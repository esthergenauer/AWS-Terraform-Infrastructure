#!/usr/bin/env python3
"""
Sync non-secret environment variables from env.shared to Elastic Beanstalk.
Copy this file to scripts/sync_eb_env.py in the backend repository.
"""
from __future__ import annotations

import os
import sys
from pathlib import Path

import boto3
from botocore.exceptions import ClientError

RESERVED_KEYS = {
    "DB_HOST",
    "DB_NAME",
    "DB_USER",
    "DB_PASSWORD",
    "DB_SECRET_ARN",
    "DB_PORT",
    "AWS_REGION",
    "AWS_DEFAULT_REGION",
}

NAMESPACE = "aws:elasticbeanstalk:application:environment"
ENV_FILE = Path(os.getenv("ENV_SHARED_FILE", "env.shared"))


def parse_env_file(path: Path) -> dict[str, str]:
    if not path.exists():
        print(f"[sync_eb_env] {path} not found — skipping sync")
        return {}

    variables: dict[str, str] = {}
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        if "=" not in line:
            print(f"[sync_eb_env] skip invalid line: {line!r}")
            continue

        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip().strip('"').strip("'")

        if not key.replace("_", "").isalnum():
            print(f"[sync_eb_env] skip invalid key: {key!r}")
            continue
        if key in RESERVED_KEYS:
            print(f"[sync_eb_env] skip reserved key: {key}")
            continue

        variables[key] = value

    return variables


def get_current_env_map(eb, app_name: str, env_name: str) -> dict[str, str]:
    response = eb.describe_configuration_settings(
        ApplicationName=app_name,
        EnvironmentName=env_name,
    )
    settings = response["ConfigurationSettings"][0]["OptionSettings"]
    return {
        setting["OptionName"]: setting["Value"]
        for setting in settings
        if setting.get("Namespace") == NAMESPACE
        and "OptionName" in setting
        and "Value" in setting
    }


def main() -> int:
    app_name = os.environ.get("EB_APPLICATION_NAME")
    env_name = os.environ.get("EB_ENVIRONMENT_NAME")
    region = os.environ.get("AWS_REGION") or os.environ.get("AWS_DEFAULT_REGION", "eu-north-1")

    if not app_name or not env_name:
        print(
            "[sync_eb_env] EB_APPLICATION_NAME / EB_ENVIRONMENT_NAME are required",
            file=sys.stderr,
        )
        return 1

    desired = parse_env_file(ENV_FILE)
    if not desired:
        print("[sync_eb_env] nothing to sync")
        return 0

    eb = boto3.client("elasticbeanstalk", region_name=region)
    current = get_current_env_map(eb, app_name, env_name)

    changes = {key: value for key, value in desired.items() if current.get(key) != value}
    if not changes:
        print("[sync_eb_env] EB already up to date")
        return 0

    print(f"[sync_eb_env] updating {len(changes)} variable(s): {', '.join(sorted(changes))}")

    option_settings = [
        {"Namespace": NAMESPACE, "OptionName": key, "Value": value}
        for key, value in changes.items()
    ]

    try:
        eb.update_environment(
            EnvironmentName=env_name,
            OptionSettings=option_settings,
        )
    except ClientError as exc:
        print(f"[sync_eb_env] update failed: {exc}", file=sys.stderr)
        return 1

    print("[sync_eb_env] update requested successfully")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
