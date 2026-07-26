variable "name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_id" {
  description = "Public subnet for the bastion"
  type        = string
}

variable "instance_type" {
  type    = string
  default = "t4g.nano"
}

variable "tags" {
  type    = map(string)
  default = {}
}
