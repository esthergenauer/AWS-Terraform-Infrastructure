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

variable "network_name" {
  description = "Prefix for VPC and subnet names in this environment"
  type        = string
  default     = "shuli-dev"
}

variable "vpc_cidr" {
  description = "VPC CIDR — use a unique range per project/environment"
  type        = string
  default     = "10.1.0.0/16"
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.1.1.0/24", "10.1.2.0/24"]
}

variable "private_subnet_cidrs" {
  type    = list(string)
  default = ["10.1.10.0/24", "10.1.11.0/24"]
}

variable "availability_zones" {
  type    = list(string)
  default = []
}

variable "rds_name" {
  type    = string
  default = "shuli-dev-db"
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
  default = "shuli_dev"
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
  default = "shuli-dev"
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
  default = "shuli-dev-pipeline"
}

variable "pipeline_source_repo" {
  description = "Backend GitHub repository for CodePipeline (owner/repo) — must contain buildspec.yml"
  type        = string
}

variable "pipeline_source_branch" {
  description = "Git branch that triggers the Dev pipeline (company guide: dev)"
  type        = string
  default     = "dev"
}

variable "pipeline_frontend_branch" {
  description = "Frontend branch pulled during CodeBuild in Dev (company guide: staging)"
  type        = string
  default     = "staging"
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
