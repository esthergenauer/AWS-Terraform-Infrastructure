variable "name" {
  description = "Name prefix for network resources"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the isolated project VPC"
  type        = string
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
}

variable "availability_zones" {
  description = "AZs for subnets (empty = first two in region)"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags for all network resources"
  type        = map(string)
  default     = {}
}
