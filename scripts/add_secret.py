#!/usr/bin/env python3
"""
add_secret.py — Interactive helper for developers.

Safely adds or updates ONE key in AWS Secrets Manager secret:
  staging/app-secrets  (region: eu-north-1)

- Never prints the secret value back to the screen after entry
- Fetch-and-merge: keeps all existing keys
- Asks before overwriting an existing key
- Creates the secret automatically if it does not exist yet

Requires:
  pip install boto3
  aws configure   (Access Key + Secret + region eu-north-1)
"""

from __future__ import annotations

import getpass
import json
import re
import sys
from typing import Any

try:
    import boto3
    from botocore.exceptions import (
        ClientError,
        NoCredentialsError,
        PartialCredentialsError,
        ProfileNotFound,
        EndpointConnectionError,
        BotoCoreError,
    )
except ImportError:
    print()
    print("=" * 60)
    print("  Missing package: boto3")
    print("=" * 60)
    print()
    print("  Please run this command first, then try again:")
    print()
    print("      pip install boto3")
    print()
    sys.exit(1)


# ---------------------------------------------------------------------------
# Configuration (SBL Staging)
# ---------------------------------------------------------------------------
SECRET_NAME = "staging/app-secrets"
AWS_REGION = "eu-north-1"

# Keys must look like env vars: LETTERS, numbers, underscore
KEY_PATTERN = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")


def banner() -> None:
    print()
    print("=" * 60)
    print("   SBL Staging — Add Application Secret")
    print("   (AWS Secrets Manager · safe · no Git)")
    print("=" * 60)
    print()
    print(f"  Target secret : {SECRET_NAME}")
    print(f"  AWS region    : {AWS_REGION}")
    print()
    print("  You will be asked for:")
    print("    1) Secret Key   (example: STRIPE_API_KEY)")
    print("    2) Secret Value (hidden while you type)")
    print()
    print("  Existing secrets are NEVER deleted.")
    print("  If the key already exists, we will ask before replacing it.")
    print()


def pause(msg: str = "Press Enter to continue...") -> None:
    try:
        input(msg)
    except (EOFError, KeyboardInterrupt):
        print("\nCancelled.")
        sys.exit(0)


def ask_key() -> str:
    while True:
        print("-" * 60)
        raw = input("  Secret Key (e.g. STRIPE_API_KEY): ").strip()
        if not raw:
            print("  ✗ Key cannot be empty. Try again.")
            continue
        if not KEY_PATTERN.match(raw):
            print("  ✗ Invalid key. Use letters, numbers, underscore.")
            print("    Examples: STRIPE_API_KEY  OPENAI_API_KEY  DB_PASSWORD")
            continue
        return raw


def ask_value() -> str:
    print()
    print("  Secret Value (characters are hidden — that is normal!)")
    print("  Tip: paste with right-click, then press Enter.")
    print()
    while True:
        try:
            value = getpass.getpass("  Secret Value: ")
        except (EOFError, KeyboardInterrupt):
            print("\nCancelled.")
            sys.exit(0)

        if not value:
            print("  ✗ Value cannot be empty. Try again.")
            continue

        print()
        print("  Please type the same value again to confirm.")
        try:
            confirm = getpass.getpass("  Confirm Value: ")
        except (EOFError, KeyboardInterrupt):
            print("\nCancelled.")
            sys.exit(0)

        if value != confirm:
            print("  ✗ Values do not match. Let's try again.")
            continue

        return value


def credentials_help_and_exit() -> None:
    print()
    print("!" * 60)
    print("  AWS credentials were not found.")
    print("!" * 60)
    print()
    print("  What to do (one time setup):")
    print()
    print("  1. Open PowerShell / Terminal")
    print("  2. Run:")
    print()
    print("         aws configure")
    print()
    print("  3. Enter the Access Key + Secret Key from DevOps")
    print(f"  4. For Default region name, type:  {AWS_REGION}")
    print("  5. For Default output format, just press Enter")
    print()
    print("  Then run this script again:")
    print()
    print("         python add_secret.py")
    print()
    sys.exit(1)


def permission_help_and_exit(action: str, detail: str) -> None:
    print()
    print("!" * 60)
    print(f"  Permission denied while trying to: {action}")
    print("!" * 60)
    print()
    print("  Your AWS user cannot access this secret yet.")
    print("  Please message DevOps and ask for access to:")
    print()
    print(f"      {SECRET_NAME}")
    print()
    print(f"  Technical detail: {detail}")
    print()
    sys.exit(1)


def get_client():
    try:
        session = boto3.session.Session(region_name=AWS_REGION)
        # Force a cheap credentials check early
        session.get_credentials()
        if session.get_credentials() is None:
            credentials_help_and_exit()
        return session.client("secretsmanager")
    except (NoCredentialsError, PartialCredentialsError, ProfileNotFound):
        credentials_help_and_exit()
    except EndpointConnectionError:
        print()
        print("  ✗ Cannot reach AWS. Check your internet connection.")
        print()
        sys.exit(1)
    except BotoCoreError as exc:
        print()
        print(f"  ✗ AWS client error: {exc}")
        print()
        sys.exit(1)


def fetch_secret_dict(client) -> tuple[dict[str, Any], bool]:
    """
    Returns (data, created_new_flag).
    If the secret does not exist, returns ({}, True) — caller will create it.
    """
    try:
        response = client.get_secret_value(SecretId=SECRET_NAME)
    except ClientError as exc:
        code = exc.response.get("Error", {}).get("Code", "")
        if code in ("ResourceNotFoundException", "ResourceNotFound"):
            print(f"  ℹ Secret '{SECRET_NAME}' does not exist yet.")
            print("    It will be created with your first key.")
            print()
            return {}, True
        if code in ("AccessDeniedException", "UnrecognizedClientException"):
            permission_help_and_exit("read the secret", code)
        if code in ("ExpiredTokenException", "InvalidClientTokenId", "InvalidSignatureException"):
            credentials_help_and_exit()
        print(f"  ✗ Unexpected AWS error while reading: {code}")
        print(f"    {exc}")
        sys.exit(1)

    raw = response.get("SecretString") or "{}"
    try:
        data = json.loads(raw)
    except json.JSONDecodeError:
        print()
        print("  ✗ The secret in AWS is not valid JSON.")
        print("    Please contact DevOps before continuing.")
        print()
        sys.exit(1)

    if not isinstance(data, dict):
        print()
        print("  ✗ The secret must be a JSON object (key/value map).")
        print("    Please contact DevOps before continuing.")
        print()
        sys.exit(1)

    return data, False


def save_secret(client, data: dict[str, Any], create_new: bool) -> None:
    payload = json.dumps(data, ensure_ascii=False, indent=2, sort_keys=True)
    try:
        if create_new:
            client.create_secret(
                Name=SECRET_NAME,
                Description="SBL staging application secrets (managed by developers via add_secret.py)",
                SecretString=payload,
                Tags=[
                    {"Key": "Project", "Value": "shuli"},
                    {"Key": "Environment", "Value": "staging"},
                    {"Key": "ManagedBy", "Value": "add_secret.py"},
                ],
            )
        else:
            client.put_secret_value(SecretId=SECRET_NAME, SecretString=payload)
    except ClientError as exc:
        code = exc.response.get("Error", {}).get("Code", "")
        if code in ("AccessDeniedException", "UnrecognizedClientException"):
            permission_help_and_exit("save the secret", code)
        if code in ("ExpiredTokenException", "InvalidClientTokenId", "InvalidSignatureException"):
            credentials_help_and_exit()
        print(f"  ✗ Unexpected AWS error while saving: {code}")
        print(f"    {exc}")
        sys.exit(1)


def success_banner(key: str, action: str, total_keys: int) -> None:
    print()
    print("*" * 60)
    print()
    print("          ★★★  SUCCESS!  ★★★")
    print()
    print("*" * 60)
    print()
    print(f"  Key      : {key}")
    print(f"  Action   : {action}")
    print(f"  Secret   : {SECRET_NAME}")
    print(f"  Region   : {AWS_REGION}")
    print(f"  Total keys now in secret: {total_keys}")
    print()
    print("  Reminder:")
    print("    • Do NOT paste this value into Git / Slack / email")
    print("    • Tell DevOps if the app needs a new env var name wired")
    print()


def main() -> None:
    banner()
    pause("  Press Enter to start...")

    print()
    print("  Connecting to AWS...")
    client = get_client()
    print("  ✓ AWS connection OK")
    print()

    print("  Fetching existing secrets (merge-safe)...")
    data, create_new = fetch_secret_dict(client)
    existing_keys = sorted(data.keys())
    if existing_keys:
        print(f"  ✓ Found {len(existing_keys)} existing key(s):")
        for k in existing_keys:
            print(f"      - {k}")
    else:
        print("  ✓ No existing keys yet (empty / new secret)")
    print()

    key = ask_key()
    value = ask_value()

    action = "created"
    if key in data:
        print()
        print(f"  ⚠ Key '{key}' already exists.")
        print("    Overwriting will REPLACE the old value (other keys stay).")
        print()
        answer = input("  Type YES to overwrite, or anything else to cancel: ").strip()
        if answer != "YES":
            print()
            print("  Cancelled. Nothing was changed.")
            print()
            sys.exit(0)
        action = "updated (overwritten)"
    else:
        action = "added (new key)"

    data[key] = value

    print()
    print("  Saving to AWS Secrets Manager...")
    save_secret(client, data, create_new=create_new)
    success_banner(key, action, total_keys=len(data))


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n\n  Cancelled by user. Nothing was changed.\n")
        sys.exit(0)
