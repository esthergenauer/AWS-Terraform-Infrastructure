# AWS prerequisites

Configure local credentials and environment secrets before running Terraform.

## Sensitive values

Store secrets in `environments/<env>/secrets.auto.tfvars` (gitignored). Never commit:

- AWS access keys (use `aws configure` locally)
- Database passwords
- API keys or tokens from `.env`

## 1. IAM user (Step 0)

Create a dedicated IAM user with **AdministratorAccess** for the initial deployment.

```powershell
aws configure
```

| Setting | Example |
|---------|---------|
| Region | `eu-north-1` |
| Output | `json` |

Verify:

```powershell
aws sts get-caller-identity
```

## 2. CodeStar / CodeConnections (GitHub)

AWS Console → **CodePipeline** → **Settings** → **Connections** → create GitHub connection and approve it in GitHub (status: **Available**).

Copy the connection ARN into `codestar_connection_arn` in `secrets.auto.tfvars`.

## 3. GitHub repository (backend application)

Set `pipeline_source_repo` to the **backend application** repository (`owner/repository`), not the Terraform infrastructure repo.

The backend repo must contain `buildspec.yml` at the path configured in `buildspec_path` (default: repository root). Use [`examples/buildspec.yml`](../examples/buildspec.yml) as a starting template (Assignment Step 2).

| Environment | Pipeline source branch | CodeBuild `FRONTEND_BRANCH` |
|-------------|------------------------|-----------------------------|
| Staging | `staging` | `staging` |
| Prod | `main` | `main` |

## 4. S3 artifact bucket name

Choose a globally unique name per environment. Terraform creates the bucket.

```
# Staging example
pipeline_artifact_bucket_name = "shuli-staging-artifacts-eunorth"

# Prod — must be a different name
pipeline_artifact_bucket_name = "shuli-prod-artifacts-eunorth"
```

## 5. Elastic Beanstalk solution stack

Match the runtime to your application (Shuli backend: Python). List available stacks:

```powershell
aws elasticbeanstalk list-available-solution-stacks --region eu-north-1 --output table
```

Example:

```
eb_solution_stack_name = "64bit Amazon Linux 2023 v4.13.3 running Python 3.12"
```

## 6. RDS password

Set a strong password in `secrets.auto.tfvars`:

```
db_password = "<strong-password>"
```

## Example `secrets.auto.tfvars`

See `environments/staging/secrets.auto.tfvars.example`.

## Optional: extra Beanstalk environment variables

Mirror application `.env` keys in Terraform when needed:

```hcl
additional_eb_env_vars = {
  JWT_SECRET = "..."
}
```

## Deployment order

1. `aws configure`
2. Create and approve the GitHub connection
3. Fill `environments/staging/secrets.auto.tfvars`
4. `cd environments/staging` → `terraform init` → `terraform plan` → `terraform apply`
5. Repeat for `environments/prod` with prod-specific values
