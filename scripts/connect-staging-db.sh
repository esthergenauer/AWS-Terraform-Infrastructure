#!/usr/bin/env bash
set -euo pipefail

echo ""
echo "========================================"
echo "  Connecting to Shuli Staging DB..."
echo "========================================"
echo ""

if ! command -v aws >/dev/null 2>&1; then
  echo "ERROR: AWS CLI is not installed or not in your PATH."
  echo ""
  echo "Install AWS CLI v2:"
  echo "  https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
  echo ""
  echo "Then configure your profile:"
  echo "  aws configure"
  echo "  Region: eu-north-1"
  echo ""
  echo "You also need the Session Manager plugin:"
  echo "  https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html"
  exit 1
fi

echo "Tunnel: localhost:5432 -> shuli-staging-db (PostgreSQL 5432)"
echo ""
echo "Keep this terminal OPEN while using pgAdmin or DBeaver."
echo "Press Ctrl+C to disconnect the tunnel."
echo ""

aws ssm start-session \
  --target i-069242cd0301a2c7e \
  --region eu-north-1 \
  --document-name AWS-StartPortForwardingSessionToRemoteHost \
  --parameters host="shuli-staging-db.cn6uwqem6nuu.eu-north-1.rds.amazonaws.com",portNumber="5432",localPortNumber="5432"
