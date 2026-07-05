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

variable "tags" {
  type    = map(string)
  default = {}
}
