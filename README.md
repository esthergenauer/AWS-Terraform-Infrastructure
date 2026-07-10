# SBL Infrastructure

Terraform-managed AWS infrastructure for the **SBL (Shuli)** SaaS platform.  
This repository provisions staging and production environments: Elastic Beanstalk, RDS PostgreSQL, CodePipeline, SSM bastion access, CloudWatch→Slack alerting, and **Grafana Cloud** CloudWatch integration.

| | |
|--|--|
| **Cloud** | AWS |
| **Region** | `eu-north-1` |
| **Account** | `036318543774` |
| **IaC** | Terraform ≥ 1.5 · AWS provider ~> 5.0 |
| **Network** | AWS **Default VPC** (no custom VPC / NAT) |

**Related application repos**

| Repository | Role |
|------------|------|
| [StarUP-Solutions/sbl-backend](https://github.com/StarUP-Solutions/sbl-backend) | FastAPI API, Dockerfile, CodePipeline source |
| [StarUP-Solutions/sbl-frontend](https://github.com/StarUP-Solutions/sbl-frontend) | React + Vite UI (cloned during CodeBuild) |
| [StarUP-Solutions/sbl-infrastructure](https://github.com/StarUP-Solutions/sbl-infrastructure) | This repo — Terraform only |

---

## Overview

### Staging runtime

SBL Staging runs a single deployable unit on **AWS Elastic Beanstalk**: a Docker image that packages the **FastAPI** backend and the built **React** frontend (static files served by FastAPI). Persistent data lives on **Amazon RDS PostgreSQL 15** (`shuli-staging-db` / database `shuli_staging`), encrypted at rest, with `rds.force_ssl = 1`.

| Layer | Staging resource | Notes |
|-------|------------------|-------|
| **Compute** | EB `shuli-staging` · SingleInstance · `t4g.micro` | App + UI on one instance |
| **Database** | RDS `shuli-staging-db` · `db.t4g.micro` · Single-AZ | SG: EB + SSM bastion only |
| **CI/CD** | CodePipeline `shuli-staging-pipeline` | Source → Build → Deploy on `staging` pushes |
| **Bastion** | SSM-managed EC2 | Port-forward to RDS (no public DB) |
| **Alerts** | CloudWatch → SNS → Lambda → Slack | See [`environments/staging/MONITORING.md`](environments/staging/MONITORING.md) |
| **Dashboards** | **Grafana Cloud (Free Tier)** | Pulls native CloudWatch **metrics** and **logs** via cross-account IAM |

### Observability model

```
AWS CloudWatch (metrics + logs)
        │
        ├──► CloudWatch Alarms → SNS → Lambda → Slack     (paging / ops alerts)
        │
        └──► Grafana Cloud  ←── sts:AssumeRole ──  IAM role in our account
             (dashboards, Explore, health checks)
```

Grafana Cloud does **not** require agents on Beanstalk. It queries CloudWatch APIs in `eu-north-1` after assuming `shuli-staging-grafana-cloud`.

Deep dive: [`environments/staging/README.md`](environments/staging/README.md) · Topology: [`ARCHITECTURE.md`](ARCHITECTURE.md)

---

## Architecture & Security (Cross-Account IAM)

### How Grafana Cloud connects to Staging

```
┌─────────────────────────┐     sts:AssumeRole          ┌────────────────────────────────┐
│  Grafana Cloud          │  + sts:ExternalId           │  AWS 036318543774 (Staging)    │
│  AWS Account            │ ──────────────────────────► │  Role: shuli-staging-           │
│  (default 008923505280) │                             │        grafana-cloud            │
│                         │ ◄── GetMetricData / Logs ── │  Policy: …-metrics (read-only)  │
└─────────────────────────┘                             └────────────────────────────────┘
```

| Control | Detail |
|---------|--------|
| **IAM Role** | `shuli-staging-grafana-cloud` |
| **Trust** | `sts:AssumeRole` from Grafana Cloud’s AWS account only |
| **External ID** | Trust policy enforces `Condition.StringEquals["sts:ExternalId"]` |
| **Terraform** | Isolated file: [`environments/staging/grafana_iam.tf`](environments/staging/grafana_iam.tf) |
| **Output** | `grafana_cloud_iam_role_arn` — paste into Grafana connection settings |

This pattern prevents the [confused deputy](https://docs.aws.amazon.com/IAM/latest/UserGuide/confused-deputy.html) problem: even if another party knows the role ARN, they cannot assume it without the unique External ID issued by *your* Grafana Cloud stack.

### Security Best Practice — External ID

> **`grafana_cloud_external_id` is highly sensitive.**
>
> | Rule | Requirement |
> |------|-------------|
> | **Never** hardcode in Terraform source | ✅ |
> | **Never** store in `secrets.auto.tfvars` or any committed `.tfvars` | ✅ |
> | **Never** commit to Git | ✅ |
> | **Only** inject at runtime via environment variables | ✅ |
>
> PowerShell (session-scoped):
>
> ```powershell
> $env:TF_VAR_grafana_cloud_external_id = "<value-from-Grafana-Cloud-UI>"
> ```
>
> Clear after apply:
>
> ```powershell
> Remove-Item Env:TF_VAR_grafana_cloud_external_id
> ```

The Grafana Cloud AWS account ID defaults to Grafana Labs’ shared CloudWatch account (`008923505280`). Override with `TF_VAR_grafana_cloud_aws_account_id` only if the Grafana UI shows a different ID.

### Broader staging security (non-Grafana)

| Control | Status |
|---------|--------|
| Default VPC only (org quota / cost) | ✅ |
| RDS private + SSL (`force_ssl=1`) + `prevent_destroy` | ✅ |
| Master password `ignore_changes` (no accidental rotation) | ✅ |
| SSM bastion (no SSH ingress) | ✅ |
| Secrets Manager for DB credentials / webhooks | ✅ |
| Pipeline DevSecOps (Trivy + TruffleHog) | ✅ (application buildspec) |

---

## Minimal Required Permissions (Least Privilege)

Policy name: **`shuli-staging-grafana-cloud-metrics`**

| Category | IAM Action | Purpose |
|----------|------------|---------|
| **Metrics** | `cloudwatch:GetMetricData` | Time-series for dashboards & Explore |
| **Metrics** | `cloudwatch:ListMetrics` | Metric / namespace discovery |
| **Tags** | `tag:GetResources` | Resource-tag enrichment for filters |
| **Logs** | `logs:DescribeLogGroups` | Log group discovery |
| **Logs** | `logs:GetLogEvents` | Read log events |
| **Logs** | `logs:FilterLogEvents` | Filtered queries **and** Grafana’s automated **health check** verification |

No write APIs. No access to Secrets Manager, RDS data APIs, or Elastic Beanstalk mutate APIs.

---

## Deployment & Run Guide (PowerShell)

### Prerequisites

1. AWS credentials with rights to manage IAM, EB, RDS, etc. in account `036318543774`
2. Terraform installed and initialized in `environments/staging`
3. Non-secret staging values in `secrets.auto.tfvars` (gitignored) — see [`AWS_SETUP.md`](AWS_SETUP.md)
4. Grafana Cloud External ID copied from **Connections → AWS → CloudWatch**

### Apply Staging (including Grafana IAM) without exposing secrets

```powershell
cd "environments/staging"

# Inject External ID at runtime only — do NOT write this to any .tfvars file
$env:TF_VAR_grafana_cloud_external_id = "<PASTE_EXTERNAL_ID_FROM_GRAFANA>"

terraform plan
terraform apply

# Copy Role ARN into Grafana Cloud → CloudWatch connection (region: eu-north-1)
terraform output -raw grafana_cloud_iam_role_arn

# Remove secret from the shell session
Remove-Item Env:TF_VAR_grafana_cloud_external_id
```

### First-time staging bootstrap (non-Grafana secrets)

```powershell
cd environments\staging
copy secrets.auto.tfvars.example secrets.auto.tfvars
# Edit secrets.auto.tfvars — passwords, CodeStar ARN, artifact bucket, EB solution stack
# Do NOT put grafana_cloud_external_id in that file
terraform init
```

Then follow the Grafana inject + `terraform apply` steps above.

### After Grafana connection is healthy

1. In Grafana Cloud, import marketplace dashboards for **Amazon RDS**, **Amazon EC2**, and Elastic Beanstalk–oriented AWS views.
2. Set the data source region to **`eu-north-1`**.
3. Keep Slack paging via CloudWatch alarms ([`MONITORING.md`](environments/staging/MONITORING.md)) — Grafana is for visualization; SNS/Lambda remains the ops alert path.

---

## Repository Structure

```
sbl-infrastructure/
├── ARCHITECTURE.md              # Full system topology
├── AWS_SETUP.md                 # Prerequisites & secrets setup
├── README.md                    # This file
├── examples/buildspec.yml       # Staging pipeline buildspec source
├── modules/
│   ├── bastion/                 # SSM bastion
│   ├── eb/                      # Elastic Beanstalk + IAM
│   ├── network/                 # Custom VPC (unused — Default VPC in use)
│   ├── pipeline/                # CodePipeline + CodeBuild
│   ├── rds/                     # PostgreSQL + SSL parameter group
│   └── waf/                     # WAFv2 (production ALB)
└── environments/
    ├── staging/
    │   ├── main.tf              # EB, RDS, bastion, pipeline
    │   ├── monitoring.tf        # CloudWatch → SNS → Slack
    │   ├── grafana_iam.tf       # Grafana Cloud cross-account IAM
    │   ├── README.md            # Grafana Cloud runbook (detailed)
    │   └── MONITORING.md        # Slack alarm apply notes
    └── prod/
        ├── main.tf              # LoadBalanced EB, Multi-AZ RDS
        ├── waf.tf               # ALB WAF association
        └── finops.tf            # Night/morning ASG schedules
```

### Staging vs Production (summary)

| Component | Staging | Production |
|-----------|---------|------------|
| EB | SingleInstance, `t4g.micro` | LoadBalanced ALB, `t4g.small`, 2–4 instances |
| RDS | `db.t4g.micro`, Single-AZ | `db.t4g.small`, Multi-AZ, 30-day backups |
| Pipeline branch | `staging` | `main` |
| Bastion | Yes | Yes (in Terraform) |
| Slack monitoring | Yes | Not yet |
| Grafana Cloud IAM | Yes | Not yet |
| WAF | No | Yes (OWASP managed rules) |
| FinOps ASG schedules | No | 23:00 → 1 / 07:00 → 2 |

---

## Local developer access (Staging RDS)

```powershell
aws ssm start-session --target <bastion_instance_id> `
  --document-name AWS-StartPortForwardingSessionToRemoteHost `
  --parameters host="<rds-host>",portNumber="5432",localPortNumber="5432"
```

Full guide: [`scripts/DEVELOPER_DB_ACCESS.md`](scripts/DEVELOPER_DB_ACCESS.md)

---

## Documentation Index

| Document | Purpose |
|----------|---------|
| [`ARCHITECTURE.md`](ARCHITECTURE.md) | End-to-end topology (EB, RDS, pipeline, bastion) |
| [`AWS_SETUP.md`](AWS_SETUP.md) | IAM, CodeStar, `secrets.auto.tfvars` |
| [`environments/staging/README.md`](environments/staging/README.md) | Grafana Cloud IAM — full runbook |
| [`environments/staging/MONITORING.md`](environments/staging/MONITORING.md) | CloudWatch → Slack alarms |
| [`scripts/DEVELOPER_DB_ACCESS.md`](scripts/DEVELOPER_DB_ACCESS.md) | SSM tunnel + SSL + per-dev DB roles |
| [`scripts/SECURITY_SCANNING.md`](scripts/SECURITY_SCANNING.md) | Trivy / TruffleHog pipeline gate |

---

*Keep External IDs and passwords out of Git. Prefer runtime injection (`TF_VAR_*`) and gitignored `secrets.auto.tfvars` for non-Grafana secrets only.*
