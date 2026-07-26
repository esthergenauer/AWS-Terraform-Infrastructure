variable "name" {
  type = string
}

variable "environment" {
  type = string

  validation {
    condition     = contains(["staging", "prod"], var.environment)
    error_message = "environment must be staging or prod."
  }
}

variable "source_repo" {
  description = "GitHub owner/repo"
  type        = string
}

variable "source_branch" {
  description = "Pipeline source branch: staging (staging env) or main (prod env)"
  type        = string
}

variable "frontend_branch" {
  description = "Branch for frontend pull in buildspec"
  type        = string
}

variable "frontend_repo" {
  description = "GitHub owner/repo for frontend clone in CodeBuild"
  type        = string
  default     = "StarUP-Solutions/sbl-frontend"
}

variable "github_token_secret_arn" {
  description = "Optional Secrets Manager ARN (plain-text PAT) for private frontend clone"
  type        = string
  default     = null
}

variable "security_alert_secret_name" {
  description = "Secrets Manager secret name for Slack/Discord webhook on security scan failure"
  type        = string
  default     = null
}

variable "codestar_connection_arn" {
  type = string
}

variable "artifact_bucket_name" {
  type = string
}

variable "buildspec_path" {
  type    = string
  default = "buildspec.yml"
}

variable "codebuild_compute_type" {
  type    = string
  default = "BUILD_GENERAL1_SMALL"
}

variable "eb_application_name" {
  type = string
}

variable "eb_environment_name" {
  type = string
}

variable "eb_service_role_arn" {
  description = "Elastic Beanstalk service role ARN used during deploy/CloudFormation execution"
  type        = string
  default     = null
}

variable "tags" {
  type    = map(string)
  default = {}
}
