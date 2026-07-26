variable "name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  description = "Private subnet IDs"
  type        = list(string)
}

variable "eb_security_group_id" {
  description = "Elastic Beanstalk instance security group"
  type        = string
}

variable "bastion_security_group_id" {
  description = "Optional bastion SG for Dev local access via port forwarding"
  type        = string
  default     = null
}

variable "developer_access_cidr_blocks" {
  description = "Developer public IPs allowed to connect to PostgreSQL (staging)"
  type        = list(string)
  default     = []
}

variable "publicly_accessible" {
  description = "Allow direct internet access to RDS when developer CIDRs are configured"
  type        = bool
  default     = false
}

variable "instance_class" {
  description = "db.t4g.micro (Dev) or larger (Prod)"
  type        = string
}

variable "allocated_storage" {
  type = number
}

variable "max_allocated_storage" {
  type    = number
  default = 0
}

variable "engine_version" {
  type    = string
  default = "15"
}

variable "db_name" {
  type = string
}

variable "username" {
  type = string
}

variable "environment" {
  description = "staging | prod — controls Secrets Manager recovery window"
  type        = string
  default     = "staging"
}

variable "password" {
  description = "Existing RDS master password. Keep current value for live DBs; omit only for brand-new databases."
  type        = string
  sensitive   = true
  default     = null
}

variable "multi_az" {
  type    = bool
  default = false
}

variable "backup_retention_period" {
  type    = number
  default = 7
}

variable "skip_final_snapshot" {
  type    = bool
  default = true
}

variable "storage_encrypted" {
  type    = bool
  default = true
}

variable "tags" {
  type    = map(string)
  default = {}
}
