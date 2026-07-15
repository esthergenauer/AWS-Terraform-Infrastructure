# Developer Database Access — SBL Staging

This guide documents the **approved** paths to reach the staging RDS PostgreSQL instance.

## Network topology (preserved upgrade)

| Path | Status | Notes |
|------|--------|-------|
| **SSM Bastion tunnel** | ✅ Primary / recommended | No inbound SSH; no public RDS exposure required |
| Developer IP allowlist (`developer_access_cidr_blocks`) | ⚠️ Legacy optional | Terraform-supported; prefer SSM tunnel |
| `0.0.0.0/0` open RDS | ❌ Removed | Replaced by SG + bastion model |

Production has **no bastion** — application access is from Elastic Beanstalk only.

---

## 1. Local development (no AWS)

Use `sbl-backend/docker-compose.yml`:

```powershell
cd sbl-backend
docker compose up -d
```

Connection:

| Field | Value |
|-------|-------|
| Host | `localhost` |
| Port | `5432` |
| Database | `sbl_local` |
| User | `sbl_dev` |
| Password | `sbl_dev_local_only` |

---

## 2. Staging RDS via SSM port forwarding

### Prerequisites (one-time)

1. AWS CLI + Session Manager plugin installed
2. IAM user `sbl-dev-tunnel` credentials from DevOps
3. `aws configure` → region `eu-north-1`

### Open tunnel (keep terminal open)

**Recommended — use the helper script:**

| OS | Script |
|----|--------|
| Windows | [`connect-staging-db.bat`](connect-staging-db.bat) — double-click or run from CMD |
| macOS / Linux | [`connect-staging-db.sh`](connect-staging-db.sh) — `chmod +x connect-staging-db.sh && ./connect-staging-db.sh` |

Manual command (same as the scripts):

```powershell
aws ssm start-session `
  --target i-069242cd0301a2c7e `
  --region eu-north-1 `
  --document-name AWS-StartPortForwardingSessionToRemoteHost `
  --parameters host="shuli-staging-db.cn6uwqem6nuu.eu-north-1.rds.amazonaws.com",portNumber="5432",localPortNumber="5432"
```

> **Port conflict (Windows):** If you have local PostgreSQL on port 5432, change `localPortNumber` to `5433` in the script and connect pgAdmin to `localhost:5433`.

### pgAdmin / DBeaver

| Field | Value |
|-------|-------|
| Host | `localhost` |
| Port | `5432` |
| Database | `shuli_staging` |
| Username | `dev_<yourname>` (personal role) |
| SSL | **Require** (`rds.force_ssl = 1`) |
| Root cert | [RDS eu-north-1 bundle](https://truststore.pki.rds.amazonaws.com/eu-north-1/eu-north-1-bundle.pem) |

---

## 3. Per-developer database roles

Use `scripts/db/create-developer-role.template.sql`:

1. DevOps generates a unique password per developer
2. Substitute `{{DEV_USERNAME}}` and `{{DEV_PASSWORD}}`
3. Run script connected to `shuli_staging` as master user (break-glass only)

**Never** share the RDS master password with developers.

---

## 4. Secure credential delivery

| Method | Approved? | How |
|--------|-----------|-----|
| Slack / email plaintext | ❌ | Never |
| Git / PR | ❌ | Never |
| **AWS Secrets Manager** | ✅ | Store `{"username":"dev_x","password":"..."}` per developer |
| **1:1 private handoff** | ✅ | DevOps sends password once via secure DM; developer rotates if supported |
| **Secrets Manager + console** | ✅ | DevOps creates secret; developer reads via IAM-scoped `GetSecretValue` |

Recommended secret naming:

```text
staging/db-developer/<username>
```

Example CLI (DevOps only):

```powershell
aws secretsmanager create-secret `
  --name "staging/db-developer/dev_avigail" `
  --secret-string '{"username":"dev_avigail","password":"<GENERATED>","database":"shuli_staging","host":"via-ssm-tunnel-localhost","port":5432}' `
  --region eu-north-1
```

---

## 5. SSL enforcement

Terraform sets `rds.force_ssl = 1` on the RDS parameter group.  
Clients **must** use SSL when connecting to AWS RDS.
