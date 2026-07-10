# DevSecOps — Pipeline Security Scanning & Alerts

Automated **Trivy** (vulnerabilities + embedded secrets) and **TruffleHog** (leaked credentials) run in every CodePipeline build **before** the deploy artifact is produced.

If either scanner fails, the build **stops** and a Slack/Discord notification is sent automatically.

---

## What developers see when a scan fails

> Build Failed due to Security Violation. A hardcoded secret or critical vulnerability was detected. Please check the pipeline logs, remove the secret/vulnerability, move it to env.shared/Secrets Manager, and push again.

The message includes the CodeBuild build ID and environment (`staging` / `prod`).

---

## Hook up the webhook (one-time, per environment)

### Option A — Slack (recommended)

1. In Slack: **Apps → Incoming Webhooks → Add to channel** (e.g. `#sbl-deployments`).
2. Copy the webhook URL (`https://hooks.slack.com/services/...`).
3. Store in AWS Secrets Manager:

```powershell
# Staging
aws secretsmanager create-secret `
  --name staging/slack-alerts-webhook `
  --secret-string "https://hooks.slack.com/services/YOUR/WEBHOOK/URL" `
  --region eu-north-1

# Production
aws secretsmanager create-secret `
  --name prod/slack-alerts-webhook `
  --secret-string "https://hooks.slack.com/services/YOUR/WEBHOOK/URL" `
  --region eu-north-1
```

Plain URL string **or** JSON `{"webhook_url":"https://..."}` both work.

### Option B — Discord

1. Server Settings → Integrations → Webhooks → New Webhook.
2. Copy URL (`https://discord.com/api/webhooks/...`).
3. Store using the same `aws secretsmanager create-secret` commands above.

Discord accepts the same JSON payload shape Slack uses for simple text alerts.

---

## Terraform wiring (already configured)

| Environment | Secret name | CodeBuild env var |
|-------------|-------------|-------------------|
| Staging | `staging/slack-alerts-webhook` | `SECURITY_ALERT_SECRET_NAME` |
| Production | `prod/slack-alerts-webhook` | `SECURITY_ALERT_SECRET_NAME` |

CodeBuild IAM is granted `secretsmanager:GetSecretValue` on that secret only.

---

## Files involved

| File | Purpose |
|------|---------|
| `sbl-backend/scripts/run_security_scan.sh` | Installs scanners, runs gate, triggers alert on failure |
| `sbl-backend/scripts/notify_security_failure.py` | Fetches webhook from Secrets Manager, posts message |
| `sbl-backend/buildspec.yml` | Invokes security gate in the `build` phase |
| `sbl-infrastructure/examples/buildspec.yml` | Same (staging pipeline source) |
| `sbl-backend/.github/workflows/ci.yml` | PR-level Trivy + TruffleHog (no webhook — logs only) |

---

## Self-service fix workflow

1. Open **CodeBuild** → failed build → **Phase details** → find Trivy/TruffleHog output.
2. Remove hardcoded secret from code; use `.env` locally and **Secrets Manager** in cloud (`scripts/add_secret.py`).
3. For dependency CVEs: upgrade the package in `requirements.txt` / `package.json`.
4. Push again — pipeline re-runs automatically.

No DevOps escalation required for scan failures.
