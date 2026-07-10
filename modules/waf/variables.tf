variable "name" {
  description = "WAF Web ACL name prefix"
  type        = string
}

variable "alb_arn" {
  description = "Application Load Balancer ARN to associate with the Web ACL"
  type        = string
}

variable "rate_limit" {
  description = "Max requests per 5-minute window per IP (0 = disabled)"
  type        = number
  default     = 2000
}

variable "tags" {
  type    = map(string)
  default = {}
}
