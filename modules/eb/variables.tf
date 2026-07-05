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

variable "db_password" {
  type      = string
  sensitive = true
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
