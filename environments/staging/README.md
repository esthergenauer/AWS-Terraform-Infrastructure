# Grafana Cloud — Staging CloudWatch Integration

Operational runbook for the **Grafana Cloud (Free Tier)** cross-account IAM bridge that pulls native AWS CloudWatch **metrics** and **logs** from the SBL staging account into Grafana Cloud.

| Item | Value |
|------|-------|
| **Environment** | Staging (`eu-north-1`) |
| **AWS Account** | `036318543774` |
| **Terraform file** | [`grafana_iam.tf`](./grafana_iam.tf) |
| **IAM Role** | `shuli-staging-grafana-cloud` |
| **IAM Policy** | `shuli-staging-grafana-cloud-metrics` |
| **Terraform output** | `grafana_cloud_iam_role_arn` |

---

## Overview

SBL staging observability is dual-path:

1. **In-account alerting** — CloudWatch Alarms → SNS → Lambda → Slack ([`MONITORING.md`](./MONITORING.md))
2. **Grafana Cloud dashboards** — Grafana Cloud assumes a dedicated IAM role in our account and reads CloudWatch metrics/logs over the AWS API

This document covers path **2** only. No agents, exporters, or Prometheus scrapers are required on Elastic Beanstalk — Grafana Cloud queries CloudWatch directly.

---

## Architecture & Security (Cross-Account IAM)

```
┌─────────────────────┐         sts:AssumeRole          ┌──────────────────────────────┐
│  Grafana Cloud      │ ───────────────────────────────► │  AWS Account 036318543774    │
│  (Grafana Labs AWS) │   + sts:ExternalId (required)    │  Role: shuli-staging-         │
│  Account (default)  │                                  │        grafana-cloud          │
│  008923505280       │ ◄──── GetMetricData / Logs ───── │  Policy: …-metrics (R/O)     │
└─────────────────────┘                                  └──────────────────────────────┘
```

| Control | Implementation |
|---------|----------------|
| **Trust** | `sts:AssumeRole` allowed only from the Grafana Cloud AWS account |
| **External ID** | Trust policy `Condition.StringEquals["sts:ExternalId"]` — blocks confused-deputy attacks |
| **Privilege** | Read-only CloudWatch metrics + Logs APIs (no write, no IAM, no data-plane access to RDS/EB) |
| **Scope** | Staging Terraform stack only — isolated in `grafana_iam.tf` |

The role name is derived as `${project_name}-staging-grafana-cloud` (default: **`shuli-staging-grafana-cloud`**).

---

### Security Best Practice Notice

> **`grafana_cloud_external_id` is classified as sensitive.**
>
> - It is **never** hardcoded in Terraform source
> - It is **never** written to `secrets.auto.tfvars` or any committed `.tfvars`
> - It is **never** checked into Git
>
> Inject it **at runtime only** via the Terraform environment variable convention:
>
> ```powershell
> $env:TF_VAR_grafana_cloud_external_id = "<value-from-Grafana-Cloud-UI>"
> ```
>
> After apply, clear it from the shell session:
>
> ```powershell
> Remove-Item Env:TF_VAR_grafana_cloud_external_id
> ```

The Grafana Cloud AWS account ID defaults to Grafana Labs’ shared CloudWatch integration account (`008923505280`). Override only if the Grafana UI shows a different account ID:

```powershell
$env:TF_VAR_grafana_cloud_aws_account_id = "<id-from-Grafana-UI>"
```

---

## Step-by-Step Deployment Guide

### Step 1 — Extract External ID (and Account ID) from Grafana Cloud

1. Sign in to [Grafana Cloud](https://grafana.com/).
2. Open **Connections** → **AWS** → **CloudWatch** (or **Add new connection** → CloudWatch).
3. Copy:
   - **External ID** → maps to `grafana_cloud_external_id` (sensitive)
   - **AWS Account ID** (if shown and different from the default) → `grafana_cloud_aws_account_id`
4. Note the target AWS region for this stack: **`eu-north-1`**.

### Step 2 — Inject variables and apply Terraform (Staging)

From the repository root (`sbl-infrastructure`), in **PowerShell**:

```powershell
cd "environments/staging"

# Required — paste External ID from Grafana Cloud (do not commit this value)
$env:TF_VAR_grafana_cloud_external_id = "<PASTE_EXTERNAL_ID>"

# Optional — only if Grafana shows a non-default account ID
# $env:TF_VAR_grafana_cloud_aws_account_id = "008923505280"

terraform plan
terraform apply
```

**Expected plan shape for a first-time Grafana apply:** create role + policy + attachment (`+`). Subsequent permission updates (e.g. Logs actions) are in-place policy changes (`~`) — no resource replacement.

> **Note:** Elastic Beanstalk or RDS may appear in the same plan if other staging changes are pending. Review the plan carefully. Grafana IAM itself does not replace RDS or EB.

### Step 3 — Paste the Role ARN back into Grafana

```powershell
terraform output -raw grafana_cloud_iam_role_arn
```

1. Copy the printed ARN (format: `arn:aws:iam::036318543774:role/shuli-staging-grafana-cloud`).
2. In Grafana Cloud → CloudWatch connection settings, paste:
   - **IAM Role ARN** → output above
   - **Default region** → `eu-north-1`
   - **External ID** → the same value you injected via `TF_VAR_…`
3. Run Grafana’s connection / health check.
4. Clear the secret from your shell:

```powershell
Remove-Item Env:TF_VAR_grafana_cloud_external_id
```

---

## Minimal Required Permissions (Least Privilege)

Policy: **`shuli-staging-grafana-cloud-metrics`**

| Category | IAM Action | Purpose |
|----------|------------|---------|
| **Metrics** | `cloudwatch:GetMetricData` | Time-series queries for dashboards & Explore |
| **Metrics** | `cloudwatch:ListMetrics` | Metric discovery / namespace browsing |
| **Tags** | `tag:GetResources` | Resource-tag enrichment for dimension filters |
| **Logs** | `logs:DescribeLogGroups` | Log group discovery |
| **Logs** | `logs:GetLogEvents` | Read log events |
| **Logs** | `logs:FilterLogEvents` | Filtered queries + Grafana automated **health check** verification |

No write APIs, no `*` beyond these actions, and no access to Secrets Manager, RDS data APIs, or Elastic Beanstalk mutate APIs.

---

## Post-Deployment (Visualizations)

Once the CloudWatch data source is healthy in Grafana Cloud:

1. Open **Dashboards** → **New** → **Import** (or the Grafana Cloud **Integrations / Marketplace**).
2. Import the built-in AWS dashboards in one click, for example:
   - **Amazon RDS**
   - **Amazon EC2** / **Elastic Beanstalk**-oriented AWS dashboards
3. Point each dashboard at the CloudWatch data source you just configured (`eu-north-1`).

Complementary staging alerts (CPU, 5xx, disk, RDS storage, EB health) continue to flow through Slack via [`MONITORING.md`](./MONITORING.md) — Grafana Cloud is for **visualization and exploration**, not a replacement for that alarm path.

---

## Quick Reference

| Task | Command / location |
|------|--------------------|
| Apply IAM | `terraform apply` with `TF_VAR_grafana_cloud_external_id` set |
| Get Role ARN | `terraform output -raw grafana_cloud_iam_role_arn` |
| Terraform source | [`grafana_iam.tf`](./grafana_iam.tf) |
| Variables | [`variables.tf`](./variables.tf) — `grafana_cloud_*` |
| Output | [`outputs.tf`](./outputs.tf) — `grafana_cloud_iam_role_arn` |
| Slack alarms (separate) | [`MONITORING.md`](./MONITORING.md) |

---

*Maintained as part of the SBL staging Terraform stack. Keep External IDs out of Git — always inject at runtime.*
