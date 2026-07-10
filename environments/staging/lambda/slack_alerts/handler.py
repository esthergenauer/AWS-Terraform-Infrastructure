"""
SNS → Slack alert translator for SBL Staging.

Fetches the Slack Incoming Webhook URL from Secrets Manager at runtime
(secret: staging/slack-alerts-webhook, key: webhook_url). Never hardcodes secrets.
"""

from __future__ import annotations

import json
import logging
import os
import urllib.error
import urllib.request
from typing import Any

import boto3

logger = logging.getLogger()
logger.setLevel(logging.INFO)

SECRET_NAME = os.environ.get("SLACK_WEBHOOK_SECRET_NAME", "staging/slack-alerts-webhook")
SECRET_KEY = os.environ.get("SLACK_WEBHOOK_SECRET_KEY", "webhook_url")

# Cache across warm invocations (same execution environment).
_webhook_url_cache: str | None = None


def _get_webhook_url() -> str:
    global _webhook_url_cache
    if _webhook_url_cache:
        return _webhook_url_cache

    client = boto3.client("secretsmanager")
    response = client.get_secret_value(SecretId=SECRET_NAME)
    payload = (response.get("SecretString") or "").strip()
    if not payload:
        raise ValueError(f"Secret '{SECRET_NAME}' is empty")

    url: str | None = None

    # Support both shapes:
    # 1) Plain webhook URL string
    # 2) JSON object with key webhook_url / url / webhook
    if payload.startswith("http://") or payload.startswith("https://"):
        url = payload
    else:
        try:
            parsed = json.loads(payload)
        except json.JSONDecodeError as exc:
            raise ValueError(
                f"Secret '{SECRET_NAME}' must be a webhook URL or JSON "
                f"with key '{SECRET_KEY}'"
            ) from exc

        if isinstance(parsed, dict):
            candidate = parsed.get(SECRET_KEY) or parsed.get("url") or parsed.get("webhook")
            if isinstance(candidate, str):
                url = candidate
        elif isinstance(parsed, str):
            url = parsed

    if not url or not url.startswith("http"):
        raise ValueError(
            f"Secret '{SECRET_NAME}' did not contain a valid Slack webhook URL"
        )

    _webhook_url_cache = url
    return url


def _color_for_state(state: str) -> str:
    normalized = (state or "").upper()
    if normalized == "ALARM":
        return "#E01E5A"  # red
    if normalized == "OK":
        return "#2EB67D"  # green
    return "#ECB22E"  # yellow (INSUFFICIENT_DATA / unknown)


def _emoji_for_state(state: str) -> str:
    normalized = (state or "").upper()
    if normalized == "ALARM":
        return ":rotating_light:"
    if normalized == "OK":
        return ":white_check_mark:"
    return ":warning:"


def _build_slack_payload(message: dict[str, Any], sns_subject: str | None) -> dict[str, Any]:
    alarm_name = message.get("AlarmName", "UnknownAlarm")
    new_state = message.get("NewStateValue", "UNKNOWN")
    reason = message.get("NewStateReason", "No reason provided")
    timestamp = message.get("StateChangeTime") or message.get("Timestamp") or "N/A"
    region = message.get("Region") or os.environ.get("AWS_REGION", "eu-north-1")
    description = message.get("AlarmDescription") or ""

    title = f"{_emoji_for_state(new_state)} *{alarm_name}* → `{new_state}`"
    if sns_subject:
        title = f"{_emoji_for_state(new_state)} *{sns_subject}*"

    fields = [
        {"title": "Alarm", "value": alarm_name, "short": True},
        {"title": "State", "value": new_state, "short": True},
        {"title": "Region", "value": region, "short": True},
        {"title": "Time", "value": str(timestamp), "short": True},
        {"title": "Reason", "value": reason, "short": False},
    ]
    if description:
        fields.insert(2, {"title": "Description", "value": description, "short": False})

    return {
        "text": f"SBL Staging alert: {alarm_name} is {new_state}",
        "attachments": [
            {
                "color": _color_for_state(new_state),
                "mrkdwn_in": ["text", "fields"],
                "text": title,
                "fields": fields,
                "footer": "SBL Staging · CloudWatch → SNS → Lambda → Slack",
            }
        ],
    }


def _post_to_slack(webhook_url: str, payload: dict[str, Any]) -> None:
    body = json.dumps(payload).encode("utf-8")
    request = urllib.request.Request(
        webhook_url,
        data=body,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=10) as response:
            status = getattr(response, "status", None) or response.getcode()
            logger.info("Slack webhook response status=%s", status)
    except urllib.error.HTTPError as exc:
        error_body = exc.read().decode("utf-8", errors="replace")
        logger.error("Slack HTTPError %s: %s", exc.code, error_body)
        raise
    except urllib.error.URLError as exc:
        logger.error("Slack URLError: %s", exc)
        raise


def lambda_handler(event: dict[str, Any], _context: Any) -> dict[str, Any]:
    logger.info("Received event: %s", json.dumps(event))
    webhook_url = _get_webhook_url()

    records = event.get("Records") or []
    delivered = 0

    for record in records:
        sns = record.get("Sns") or {}
        raw = sns.get("Message", "{}")
        subject = sns.get("Subject")

        try:
            message = json.loads(raw) if isinstance(raw, str) else raw
        except json.JSONDecodeError:
            message = {
                "AlarmName": subject or "SNSNotification",
                "NewStateValue": "ALARM",
                "NewStateReason": str(raw),
                "StateChangeTime": sns.get("Timestamp", "N/A"),
            }

        payload = _build_slack_payload(message, subject)
        _post_to_slack(webhook_url, payload)
        delivered += 1

    return {"statusCode": 200, "delivered": delivered}
