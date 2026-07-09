variable "aws_region" {
  type    = string
  default = "eu-north-1"
}

variable "project_name" {
  description = "Project prefix used in resource names (change for other projects)"
  type        = string
  default     = "shuli"
}

variable "common_tags" {
  type = map(string)
  default = {
    Project   = "shuli"
    ManagedBy = "terraform"
  }
}

variable "rds_name" {
  type    = string
  default = "shuli-staging-db"
}

variable "rds_instance_class" {
  type    = string
  default = "db.t4g.micro"
}

variable "rds_allocated_storage" {
  type    = number
  default = 20
}

variable "rds_engine_version" {
  type    = string
  default = "15"
}

variable "db_name" {
  type    = string
  default = "shuli_staging"
}

variable "db_username" {
  type    = string
  default = "shuli_admin"
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "developer_access_cidr_blocks" {
  description = "Add each developer public IP as x.x.x.x/32 after they report connection timeout"
  type        = list(string)
  default     = []
}

variable "eb_application_name" {
  type    = string
  default = "shuli-app"
}

variable "eb_environment_name" {
  type    = string
  default = "shuli-staging"
}

variable "eb_solution_stack_name" {
  type = string
}

variable "eb_instance_type" {
  type    = string
  default = "t4g.micro"
}

variable "additional_eb_env_vars" {
  type    = map(string)
  default = {}
}

variable "pipeline_name" {
  type    = string
  default = "shuli-staging-pipeline"
}

variable "pipeline_source_repo" {
  description = "Backend GitHub repository for CodePipeline (owner/repo) — must contain buildspec.yml"
  type        = string
}

variable "pipeline_source_branch" {
  description = "Git branch that triggers the Staging pipeline"
  type        = string
  default     = "staging"
}

variable "pipeline_frontend_branch" {
  description = "Frontend branch pulled during CodeBuild in Staging"
  type        = string
  default     = "staging"
}

variable "pipeline_frontend_repo" {
  description = "Frontend GitHub repository (owner/repo) cloned during CodeBuild"
  type        = string
  default     = "StarUP-Solutions/sbl-frontend"
}

variable "github_token_secret_arn" {
  description = "Optional Secrets Manager ARN with GitHub PAT for private frontend clone"
  type        = string
  default     = null
}

variable "codestar_connection_arn" {
  type = string
}

variable "pipeline_artifact_bucket_name" {
  type = string
}

variable "buildspec_path" {
  type    = string
  default = "buildspec.yml"
}
