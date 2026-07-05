# SBL Infrastructure

Terraform configuration for the SBL (Shuli) project on AWS, following the company DevOps guide.

## Company repositories

| Repository | Purpose |
|------------|---------|
| [StarUP-Solutions/sbl-infrastructure](https://github.com/StarUP-Solutions/sbl-infrastructure) | This repo — Terraform (VPC, RDS, EB, Pipeline) |
| [StarUP-Solutions/sbl-backend](https://github.com/StarUP-Solutions/sbl-backend) | Python backend — CodePipeline source |

CodePipeline pulls application code from **sbl-backend** only. This infrastructure repo is not used as a pipeline source.

## Architecture

| Component | Staging | Prod |
|-----------|-----|------|
| VPC | `10.1.0.0/16` | `10.2.0.0/16` |
| RDS | `db.t4g.micro` | `db.t4g.small`, Multi-AZ |
| Elastic Beanstalk | `t4g.micro`, single instance | `t4g.small`, ALB, 2–4 instances |
| Pipeline source branch | `staging` | `main` |
| Pipeline frontend branch (CodeBuild) | `staging` | `main` |
| Bastion (SSM) | yes | no |

## Structure

```
modules/
├── network/    VPC, subnets, internet gateway
├── rds/        PostgreSQL (private subnets, db-sg)
├── eb/         Elastic Beanstalk (backend + frontend)
├── pipeline/   CodePipeline → CodeBuild → Beanstalk
└── bastion/    SSM bastion for local DB access (Staging only)

environments/
├── staging/
└── prod/
```

## Deployment

```powershell
cd environments\staging
copy secrets.auto.tfvars.example secrets.auto.tfvars
# Edit secrets.auto.tfvars — see AWS_SETUP.md
terraform init
terraform plan
terraform apply
```

Repeat for `environments\prod` with separate secrets and bucket name.

## Customization for another project

| File / variable | What to change |
|-----------------|----------------|
| `common_tags`, `project_name` | Project name and tags |
| `network_name`, `vpc_cidr`, subnet CIDRs | Avoid overlap with other VPCs |
| `rds_name`, `db_name`, `eb_*_name` | Resource naming |
| `secrets.auto.tfvars` | Region, backend repo, ARN, passwords, bucket, solution stack |
| `pipeline_source_branch` / `pipeline_frontend_branch` | Override in `variables.tf` if your Git flow differs |

Sensitive values belong in `secrets.auto.tfvars` only (listed in `.gitignore`).

## Local DB access (Staging)

```powershell
aws ssm start-session --target <bastion_instance_id> `
  --document-name AWS-StartPortForwardingSessionToRemoteHost `
  --parameters host="<rds-host>",portNumber="5432",localPortNumber="5432"
```

## Documentation

- Prerequisites and secrets: [`AWS_SETUP.md`](AWS_SETUP.md)
- Architecture diagrams: [`docs/architecture/`](docs/architecture/)
