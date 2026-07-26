variable "application_name" {
  description = "Elastic Beanstalk application (backend serves frontend)"
  type        = string
}

variable "environment_name" {
  type = string
}

variable "description" {
  type    = string
  default = "Shuli backend and frontend"
}

variable "solution_stack_name" {
  type = string
}

variable "instance_type" {
  description = "t4g.micro (Dev) or larger (Prod)"
  type        = string
}

variable "environment_type" {
  description = "SingleInstance for Dev (no LB cost), LoadBalanced for Prod"
  type        = string
  default     = "LoadBalanced"

  validation {
    condition     = contains(["SingleInstance", "LoadBalanced"], var.environment_type)
    error_message = "environment_type must be SingleInstance or LoadBalanced."
  }
}

variable "vpc_id" {
  type = string
}

variable "security_group_id" {
  type = string
}

variable "instance_subnet_ids" {
  type = list(string)
}

variable "elb_subnet_ids" {
  description = "Required when environment_type is LoadBalanced"
  type        = list(string)
  default     = []
}

variable "associate_public_ip_address" {
  type    = bool
  default = true
}

variable "min_instances" {
  type    = number
  default = 1
}

variable "max_instances" {
  type    = number
  default = 1
}

variable "load_balancer_type" {
  description = "application ALB for Prod"
  type        = string
  default     = "application"
}

variable "db_host" {
  type = string
}

variable "db_name" {
  type = string
}

variable "db_user" {
  type = string
}

variable "db_secret_arn" {
  description = "Secrets Manager ARN for RDS credentials"
  type        = string
}

variable "db_password" {
  description = "Optional legacy EB env var. Keep set during migration so existing apps keep working."
  type        = string
  sensitive   = true
  default     = null
}

variable "additional_environment_variables" {
  description = "Extra EB env vars (mirror .env additions from developers)"
  type        = map(string)
  default     = {}
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "aws_region" {
  description = "AWS region (for EB platform-assets and regional bucket ARNs)"
  type        = string
}

variable "aws_account_id" {
  description = "AWS account ID (for regional EB bucket ARN)"
  type        = string
}

variable "pipeline_artifact_bucket_name" {
  description = "CodePipeline artifacts bucket EB must read during Deploy"
  type        = string
  default     = null
}

variable "publish_enhanced_health_metrics" {
  description = "Publish selected enhanced-health metrics to CloudWatch (period must be 60). EnvironmentHealth is free; other metrics incur CloudWatch custom-metric charges."
  type        = bool
  default     = true
}
