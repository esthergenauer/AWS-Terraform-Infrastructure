# AWS Infrastructure for SBL

**Terraform / AWS IaC** for a multi-environment **SaaS-style** platform (SBL / Shuli): staging + production, secure access, automated CI/CD, observability, and cost-aware production schedules.

[![Terraform](https://img.shields.io/badge/IaC-Terraform-7B42BC?logo=terraform&logoColor=white)](https://www.terraform.io/)
[![AWS](https://img.shields.io/badge/Cloud-AWS-FF9900?logo=amazon-aws&logoColor=white)](https://aws.amazon.com/)
[![Region](https://img.shields.io/badge/Region-eu--north--1-232F3E)](https://aws.amazon.com/about-aws/global-infrastructure/)

> Portfolio copy. Real secrets are not included.

---

## Context

This was my **first hands-on task** in a DevOps practicum (**July 2026**).

The ask: infrastructure for a **managed SaaS system**, automated as much as possible, with **DEV/Staging** and **Production**.

Beyond the checklist, I chose to make it **generic**: shared logic in **modules**; each site/project should mostly need a new **environment** (variables + secrets) — not a rewrite.  
In practice Shuli already uses that pattern: **two environments, same modules, mostly different inputs**.

I also pushed further on **security**, **monitoring/alerting**, and **FinOps** — so the repo shows design thinking, not only “infra that runs.”

---

## My design choices

| Choice | What I added beyond the base ask |
|--------|-----------------------------------|
| **Generic modules** | Reuse across future projects; env folders stay thin |
| **Secrets that I don’t have to “know”** | DB master password can be **generated** (`random_password`), stored in **Secrets Manager**, and read by the app via **secret ARN + IAM** |
| **SSM tunnel access** | Developers reach RDS via **Session Manager port-forward** — not by opening the DB to the internet |
| **Prod hardening** | SSL enforced on RDS, **WAF** on the ALB, stricter prod posture |
| **Observability** | **CloudWatch → SNS → Lambda → Slack**, plus **Grafana Cloud** (AssumeRole) |
| **FinOps** | Production **ASG schedules** (scale down at night / up in the morning) |

---

## Working with AI (AI-native, not AI-replaced)

I work in an **AI-native** way: I use **Cursor** and consult **Gemini** to understand options, learn DevSecOps/FinOps ideas, debug faster, and improve docs.

That is **not** copy-paste. I use AI to **think with** — while **I** own the architecture, the generic design, the security/monitoring choices, and the final implementation.

---

## Highlights

| Area | What’s in this repo |
|------|---------------------|
| **IaC** | Modular Terraform (environments + reusable modules) |
| **Compute** | Elastic Beanstalk (Docker) — SingleInstance staging, ALB + Auto Scaling production |
| **Data** | RDS PostgreSQL — encryption, `force_ssl`, Secrets Manager |
| **CI/CD** | CodePipeline + CodeBuild (Source → Build → Deploy) |
| **Security** | SSM bastion (no SSH), least-privilege IAM, WAF on prod ALB, pipeline scanning |
| **Observability** | CloudWatch → SNS → Lambda → Slack + Grafana Cloud |
| **FinOps** | Night/morning ASG schedules in production |

---

## Architecture

```
                    GitHub (backend + frontend)
                              │
                              ▼
                   AWS CodePipeline
                   Source → Build → Deploy
                              │
                              ▼
              ┌───────────────────────────────┐
              │  Elastic Beanstalk (Docker)    │
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

Developers ── SSM Session Manager ──► Bastion ──► RDS (port-forward tunnel)
Ops alerts ── CloudWatch Alarms ──► SNS → Lambda → Slack
Dashboards ── Grafana Cloud ──► AssumeRole → CloudWatch metrics/logs
```

Full topology: [`ARCHITECTURE.md`](ARCHITECTURE.md)

---

## Staging vs Production

| Component | Staging | Production |
|-----------|---------|------------|
| Elastic Beanstalk | SingleInstance · `t4g.micro` | LoadBalanced ALB · `t4g.small` · 2–4 instances |
| RDS | `db.t4g.micro` · Single-AZ | `db.t4g.small` · Multi-AZ · 30-day backups |
| Pipeline branch | `staging` | `main` |
| SSM bastion / tunnel | Yes | Yes |
| Slack monitoring | Yes | Planned |
| Grafana Cloud IAM | Yes | Planned |
| WAF | — | OWASP managed rules on ALB |
| FinOps schedules | — | Scale down at night / up in the morning |

---

## Repository structure

```
AWS-infrastructure-for-SBL/
├── ARCHITECTURE.md
├── AWS_SETUP.md
├── modules/          # bastion, eb, network, pipeline, rds, waf
├── environments/
│   ├── staging/      # + monitoring, Grafana IAM
│   └── prod/         # + WAF, FinOps schedules
├── scripts/
├── iam/
└── examples/
```

---

## Security practices (implemented)

- **No public database** — RDS only from EB + SSM bastion path
- **SSL required** — `rds.force_ssl = 1`
- **Secrets Manager** — generated/stored credentials; app uses secret ARN + IAM (not a password living in Git)
- **Bastion without SSH ingress** — Session Manager only + port-forward tunnel
- **Cross-account Grafana** — `sts:AssumeRole` + External ID
- **Production WAF** — managed rule groups on the ALB
- **Pipeline scanning** — Trivy / TruffleHog in the application buildspec

---

## Observability

```
AWS CloudWatch (metrics + logs)
        │
        ├──► Alarms → SNS → Lambda → Slack
        │
        └──► Grafana Cloud  ←── sts:AssumeRole
```

- [`environments/staging/MONITORING.md`](environments/staging/MONITORING.md)
- [`environments/staging/README.md`](environments/staging/README.md) (Grafana IAM)

---

## Quick start

```powershell
git clone https://github.com/esthergenauer/AWS-infrastructure-for-SBL.git
cd AWS-infrastructure-for-SBL\environments\staging
copy secrets.auto.tfvars.example secrets.auto.tfvars
terraform init
terraform plan
terraform apply
```

See [`AWS_SETUP.md`](AWS_SETUP.md).

---

**Esther Genauer** · Junior DevOps / Cloud Infrastructure
