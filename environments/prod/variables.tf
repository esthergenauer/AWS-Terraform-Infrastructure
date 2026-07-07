variable "aws_region" {
  type    = string
  default = "eu-north-1"
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
  default = "shuli-prod-db"
}

variable "rds_instance_class" {
  type    = string
  default = "db.t4g.small"
}

variable "rds_allocated_storage" {
  type    = number
  default = 100
}

variable "rds_max_allocated_storage" {
  type    = number
  default = 500
}

variable "rds_engine_version" {
  type    = string
  default = "15"
}

variable "db_name" {
  type    = string
  default = "shuli_prod"
}

variable "db_username" {
  type    = string
  default = "shuli_admin"
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "eb_application_name" {
  type    = string
  default = "shuli-app"
}

variable "eb_environment_name" {
  type    = string
  default = "shuli-prod"
}

variable "eb_solution_stack_name" {
  type = string
}

variable "eb_instance_type" {
  type    = string
  default = "t4g.small"
}

variable "eb_min_instances" {
  type    = number
  default = 2
}

variable "eb_max_instances" {
  type    = number
  default = 4
}

variable "additional_eb_env_vars" {
  type    = map(string)
  default = {}
}

variable "pipeline_name" {
  type    = string
  default = "shuli-prod-pipeline"
}

variable "pipeline_source_repo" {
  description = "Backend GitHub repository for CodePipeline (owner/repo) — must contain buildspec.yml"
  type        = string
}

variable "pipeline_source_branch" {
  description = "Git branch that triggers the Prod pipeline (company guide: main)"
  type        = string
  default     = "main"
}

variable "pipeline_frontend_branch" {
  description = "Frontend branch pulled during CodeBuild in Prod (company guide: main)"
  type        = string
  default     = "main"
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
