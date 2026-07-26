# SBL — System Architecture

Master reference for the Shuli (SBL) cloud platform.  
Repositories: `sbl-infrastructure`, `sbl-backend`, `sbl-frontend`.

---

## 1. High-Level Topology

```
                    GitHub (StarUP-Solutions)
                              │
              ┌───────────────┴───────────────┐
              │                               │
       sbl-backend (staging/main)     sbl-frontend (cloned in CodeBuild)
              │                               │
              └───────────────┬───────────────┘
                              ▼
                   AWS CodePipeline (V2)
                   Source → Build → Deploy
                              │
                              ▼
              ┌───────────────────────────────┐
              │  Elastic Beanstalk (Docker)    │
              │  FastAPI + static React bundle │
              │  SingleInstance (Staging)      │
              │  ALB + AutoScaling (Prod)      │
              └───────────────┬───────────────┘
                              │ SG-restricted :5432
                              ▼
              ┌───────────────────────────────┐
              │  Amazon RDS PostgreSQL         │
              │  Encrypted · force_ssl=1       │
              │  Secrets Manager credentials   │
              └───────────────────────────────┘

Developers ──SSM Session Manager──► Bastion ──► RDS (Staging only)
Local dev  ──docker compose────────► postgres:16 on localhost:5432
```

---

## 2. Application Architecture

### 2.1 Deployment unit

One **Docker image** built from `sbl-backend/Dockerfile`:

| Stage | Purpose |
|-------|---------|
| Node 20 | `npm ci` + `vite build` on cloned `sbl-frontend` |
| Python 3.12 | FastAPI app + `static/frontend/` from stage 1 |

Gunicorn + Uvicorn serves on **port 80** inside the container.

### 2.2 Request flow

1. Browser → EB environment URL (HTTP)
2. FastAPI `app/main.py` — `/health` API route
3. `StaticFiles` mount at `/` serves the React SPA (`html=True` for client routing)

### 2.3 Repository boundaries

| Repo | Responsibility |
|------|----------------|
| `sbl-backend` | API, Dockerfile, buildspec, `env.shared`, CI |
| `sbl-frontend` | React UI (cloned during pipeline build) |
| `sbl-infrastructure` | Terraform: RDS, EB, Pipeline, Bastion, Monitoring |

---

## 3. CI/CD Pipeline

| Stage | Action |
|-------|--------|
| **Source** | GitHub `sbl-backend` branch (`staging` / `main`) via CodeStar Connection |
| **Build** | CodeBuild: sync `env.shared` → EB env vars; clone frontend; package Docker context |
| **Deploy** | CodePipeline → Elastic Beanstalk Docker platform |

**Trigger:** Push/merge to `staging` (staging env). Prod uses `main`.

**Secrets:** GitHub PAT in Secrets Manager for private frontend clone. Application secrets in `staging/app-secrets` (never in Git).

---

## 4. Database Architecture

### 4.1 RDS instances

| Environment | Identifier | DB name | Class | HA |
|-------------|------------|---------|-------|-----|
| Staging | `shuli-staging-db` | `shuli_staging` | `db.t4g.micro` | Single-AZ |
| Prod | `shuli-prod-db` | `shuli_prod` | `db.t4g.small` | Multi-AZ |

Org checklist aliases: `sbl_staging` / `sbl_production` → deployed names above.

### 4.2 Security controls

- Storage encryption enabled
- `rds.force_ssl = 1` (parameter group)
- Security group: EB + Bastion only (optional developer CIDR legacy)
- Master password: `lifecycle { ignore_changes = [password] }` in Terraform
- Per-developer roles via `create-developer-role.template.sql`

### 4.3 Access paths

| Use case | Method |
|----------|--------|
| Local dev | `sbl-backend/docker-compose.yml` → `postgres:16` |
| Staging cloud | SSM port forward via bastion (see `scripts/DEVELOPER_DB_ACCESS.md`) |
| Application | `DB_HOST` / `DB_SECRET_ARN` on EB |

---

## 5. Environments (Terraform)

```
sbl-infrastructure/
├── modules/          # network, rds, eb, pipeline, bastion
└── environments/
    ├── staging/      # SingleInstance EB, bastion, monitoring
    └── prod/         # LoadBalanced ALB, Multi-AZ RDS, larger instances
```

Same modules instantiate both environments with different variables.

---

## 6. Observability (Staging)

```
CloudWatch Alarms → SNS (staging-alerts) → Lambda → Slack (#dev-alerts-ops)
```

Alarms: CPU, HTTP 5xx, StatusCheck, EnvironmentHealth, disk, RDS storage.

Webhook URL in Secrets Manager: `staging/slack-alerts-webhook`.

---

## 7. Secrets Management

| Secret | Location | Consumers |
|--------|----------|-----------|
| RDS master | Secrets Manager `shuli-staging-db/db-credentials` | EB app, DevOps |
| App keys (API tokens) | `staging/app-secrets` | EB app (via env wiring) |
| Slack webhook | `staging/slack-alerts-webhook` | Alert Lambda |
| GitHub PAT | Secrets Manager (pipeline var) | CodeBuild |

Developers add app secrets via `scripts/add_secret.py` (never Git).

---

## 8. Local Development

1. `cd sbl-backend && docker compose up -d`
2. Copy `.env.example` → `.env` in backend and frontend repos
3. Backend: `uvicorn app.main:app --reload --port 8000`
4. Frontend: `npm run dev`

See `CONTRIBUTING.md` in each application repo.

---

## 9. AI Agent Constraints

Both repos contain `.cursor/rules/` enforcing:

- Layered architecture (Routes → Services → Repositories)
- No hardcoded secrets
- Every functional endpoint requires tests (backend) / type-safe components (frontend)

---

## 10. Key URLs (Staging)

| Resource | Value |
|----------|-------|
| Web | `http://shuli-staging.eba-fqdmjmcj.eu-north-1.elasticbeanstalk.com/` |
| Health | `/health` |
| Region | `eu-north-1` |
| Account | `036318543774` |
