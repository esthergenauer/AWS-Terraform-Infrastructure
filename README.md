# AWS Infrastructure for SBL

**Production-grade AWS infrastructure as code** for a multi-environment SaaS platform (SBL / Shuli) — built with Terraform, secured by design, and wired for real CI/CD and observability.

[![Terraform](https://img.shields.io/badge/IaC-Terraform-7B42BC?logo=terraform&logoColor=white)](https://www.terraform.io/)
[![AWS](https://img.shields.io/badge/Cloud-AWS-FF9900?logo=amazon-aws&logoColor=white)](https://aws.amazon.com/)
[![Region](https://img.shields.io/badge/Region-eu--north--1-232F3E)](https://aws.amazon.com/about-aws/global-infrastructure/)
[![License](https://img.shields.io/badge/Focus-DevOps%20%7C%20Security%20%7C%20FinOps-0A66C2)](#highlights)

> Portfolio project showcasing end-to-end cloud infrastructure: staging + production, secure developer access, automated deployments, monitoring, and cost-aware production schedules.

---

## Highlights

| Area | What this repo demonstrates |
|------|-----------------------------|
| **IaC** | Modular Terraform (environments + reusable modules) |
| **Compute** | Elastic Beanstalk (Docker) — SingleInstance staging, ALB + Auto Scaling production |
| **Data** | RDS PostgreSQL with encryption, SSL enforcement, Secrets Manager |
| **CI/CD** | CodePipeline + CodeBuild (Source → Build → Deploy) |
| **Security** | SSM bastion (no SSH), least-privilege IAM, WAF on prod ALB, DevSecOps scanning |
| **Observability** | CloudWatch → SNS → Lambda → Slack + Grafana Cloud (cross-account AssumeRole) |
| **FinOps** | Night/morning ASG schedules in production to control cost |

---

## Architecture

```
                    GitHub (backend + frontend)
                              │
                              ▼
                   AWS CodePipeline (V2)
                   Source → Build → Deploy
                              │
                              ▼
              ┌───────────────────────────────┐
              │  Elastic Beanstalk (Docker)    │
              │  FastAPI + React static bundle │
              │  Staging: SingleInstance       │
              │  Prod: ALB + Auto Scaling      │
              └───────────────┬───────────────┘
                              │ SG-restricted :5432
                              ▼
              ┌───────────────────────────────┐
              │  Amazon RDS PostgreSQL         │
              │  Encrypted · force_ssl=1       │
              │  Credentials in Secrets Manager│
              └───────────────────────────────┘

Developers ── SSM Session Manager ──► Bastion ──► RDS (port-forward)
Ops alerts ── CloudWatch Alarms ──► SNS → Lambda → Slack
Dashboards ── Grafana Cloud ──► AssumeRole → CloudWatch metrics/logs
```

Full topology: [`ARCHITECTURE.md`](ARCHITECTURE.md)

---

## Tech stack

| Layer | Technologies |
|-------|----------------|
| Infrastructure | Terraform ≥ 1.5, AWS Provider ~> 5.0 |
| Compute | Elastic Beanstalk (Docker), EC2 (SSM bastion) |
| Database | Amazon RDS PostgreSQL 15 |
| Networking | Default VPC, Security Groups, (optional custom VPC module) |
| Delivery | CodePipeline, CodeBuild, CodeStar Connection |
| Security | IAM least privilege, Secrets Manager, WAFv2 (OWASP), Trivy / TruffleHog |
| Monitoring | CloudWatch Alarms, SNS, Lambda, Slack, Grafana Cloud |

---

## Staging vs Production

| Component | Staging | Production |
|-----------|---------|------------|
| Elastic Beanstalk | SingleInstance · `t4g.micro` | LoadBalanced ALB · `t4g.small` · 2–4 instances |
| RDS | `db.t4g.micro` · Single-AZ | `db.t4g.small` · Multi-AZ · 30-day backups |
| Pipeline branch | `staging` | `main` |
| SSM bastion | Yes | Yes |
| Slack monitoring | Yes | Planned |
| Grafana Cloud IAM | Yes | Planned |
| WAF | — | OWASP managed rules on ALB |
| FinOps schedules | — | Scale down at night / up in the morning |

---

## Repository structure

```
AWS-infrastructure-for-SBL/
├── ARCHITECTURE.md                 # System topology & security model
├── AWS_SETUP.md                    # Bootstrap & secrets setup
├── modules/
│   ├── bastion/                    # SSM bastion (no public SSH)
│   ├── eb/                         # Elastic Beanstalk + IAM
│   ├── network/                    # VPC module (available; default VPC in use)
│   ├── pipeline/                   # CodePipeline + CodeBuild
│   ├── rds/                        # PostgreSQL + SSL parameter group
│   └── waf/                        # WAFv2 for production ALB
├── environments/
│   ├── staging/                    # EB, RDS, pipeline, monitoring, Grafana IAM
│   └── prod/                       # LoadBalanced EB, Multi-AZ RDS, WAF, FinOps
├── scripts/                        # Developer DB access, secrets helpers
├── iam/                            # Static IAM policy documents
└── examples/                       # buildspec & env examples
```

---

## Security practices (by design)

- **No public database** — RDS reachable only from EB + SSM bastion
- **SSL required** — `rds.force_ssl = 1`
- **Secrets stay out of Git** — Secrets Manager + gitignored `*.tfvars` + runtime `TF_VAR_*`
- **Bastion without SSH ingress** — AWS Systems Manager Session Manager only
- **Cross-account Grafana** — `sts:AssumeRole` + External ID (confused-deputy protection)
- **Production WAF** — managed rule groups on the ALB
- **Pipeline scanning** — Trivy / TruffleHog gates in the application buildspec

---

## Quick start

```powershell
# 1. Clone
git clone https://github.com/EstiGenauer/AWS-infrastructure-for-SBL.git
cd AWS-infrastructure-for-SBL\environments\staging

# 2. Configure (never commit real secrets)
copy secrets.auto.tfvars.example secrets.auto.tfvars
# Edit secrets.auto.tfvars with your account values

# 3. Apply
terraform init
terraform plan
terraform apply
```

Prerequisites and secret handling: [`AWS_SETUP.md`](AWS_SETUP.md)

---

## Observability

```
AWS CloudWatch (metrics + logs)
        │
        ├──► Alarms → SNS → Lambda → Slack     (ops paging)
        │
        └──► Grafana Cloud  ←── sts:AssumeRole
             (dashboards, Explore, health checks)
```

- Staging runbook: [`environments/staging/README.md`](environments/staging/README.md)
- Slack alarms: [`environments/staging/MONITORING.md`](environments/staging/MONITORING.md)

---

## Developer database access (staging)

Secure local access via SSM port-forwarding (no open DB ports on the internet):

```powershell
aws ssm start-session --target <bastion_instance_id> `
  --document-name AWS-StartPortForwardingSessionToRemoteHost `
  --parameters host="<rds-host>",portNumber="5432",localPortNumber="5432"
```

Guide: [`scripts/DEVELOPER_DB_ACCESS.md`](scripts/DEVELOPER_DB_ACCESS.md)

---

## Documentation

| Document | Purpose |
|----------|---------|
| [`ARCHITECTURE.md`](ARCHITECTURE.md) | End-to-end topology |
| [`AWS_SETUP.md`](AWS_SETUP.md) | IAM, CodeStar, tfvars bootstrap |
| [`environments/staging/README.md`](environments/staging/README.md) | Grafana Cloud IAM runbook |
| [`environments/staging/MONITORING.md`](environments/staging/MONITORING.md) | CloudWatch → Slack |
| [`scripts/DEVELOPER_DB_ACCESS.md`](scripts/DEVELOPER_DB_ACCESS.md) | SSM tunnel + per-dev DB roles |
| [`scripts/SECURITY_SCANNING.md`](scripts/SECURITY_SCANNING.md) | Trivy / TruffleHog pipeline gate |

---

## Skills demonstrated

- Designing **multi-environment** AWS architectures (staging vs production trade-offs)
- Writing **reusable Terraform modules** and environment compositions
- Implementing **secure access patterns** (SSM, least-privilege IAM, Secrets Manager)
- Building **CI/CD** on AWS (CodePipeline / CodeBuild)
- Wiring **alerting and dashboards** (CloudWatch, Slack, Grafana Cloud)
- Applying **FinOps** controls (scheduled scale-in/out)

---

<p align="center">
  <sub>Built as a DevOps / Cloud portfolio project · Infrastructure as Code on AWS</sub>
</p>
