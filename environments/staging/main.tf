# Staging environment — deployment order: default VPC → SG → bastion → RDS → EB → pipeline
# Project-specific values: variables.tf defaults and secrets.auto.tfvars

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

locals {
  environment = "staging"
  tags        = merge(var.common_tags, { Environment = local.environment })
  vpc_id      = data.aws_vpc.default.id
  subnet_ids  = data.aws_subnets.default.ids
}

# Beanstalk SG is created here (not in the EB module) to break the RDS ↔ EB dependency cycle.
resource "aws_security_group" "beanstalk" {
  name        = "${var.eb_environment_name}-sg"
  description = "Elastic Beanstalk instances"
  vpc_id      = local.vpc_id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.tags, { Name = "${var.eb_environment_name}-sg" })
}

# Staging only: SSM bastion for port-forwarding to RDS (see README).
module "bastion" {
  source = "../../modules/bastion"

  name      = "${var.project_name}-staging"
  vpc_id    = local.vpc_id
  subnet_id = local.subnet_ids[0]

  tags = local.tags
}

module "rds" {
  source = "../../modules/rds"

  name                      = var.rds_name
  vpc_id                    = local.vpc_id
  subnet_ids                = local.subnet_ids
  eb_security_group_id         = aws_security_group.beanstalk.id
  bastion_security_group_id    = module.bastion.security_group_id
  developer_access_cidr_blocks = var.developer_access_cidr_blocks
  publicly_accessible          = length(var.developer_access_cidr_blocks) > 0

  instance_class      = var.rds_instance_class
  allocated_storage   = var.rds_allocated_storage
  engine_version      = var.rds_engine_version
  db_name             = var.db_name
  username            = var.db_username
  password            = var.db_password
  multi_az            = false
  skip_final_snapshot = true

  tags = local.tags
}

module "eb" {
  source = "../../modules/eb"

  application_name    = var.eb_application_name
  environment_name    = var.eb_environment_name
  solution_stack_name = var.eb_solution_stack_name
  instance_type       = var.eb_instance_type
  environment_type    = "SingleInstance" # Staging: no load balancer

  vpc_id                      = local.vpc_id
  security_group_id           = aws_security_group.beanstalk.id
  instance_subnet_ids         = local.subnet_ids
  associate_public_ip_address = true

  min_instances = 1
  max_instances = 1

  db_host     = module.rds.db_instance_address
  db_name     = var.db_name
  db_user     = var.db_username
  db_password = var.db_password

  additional_environment_variables = var.additional_eb_env_vars

  tags = local.tags

  depends_on = [module.rds]
}

module "pipeline" {
  source = "../../modules/pipeline"

  name                    = var.pipeline_name
  environment             = local.environment
  source_repo             = var.pipeline_source_repo
  source_branch           = var.pipeline_source_branch
  frontend_branch         = var.pipeline_frontend_branch
  codestar_connection_arn = var.codestar_connection_arn
  artifact_bucket_name    = var.pipeline_artifact_bucket_name
  buildspec_path          = var.buildspec_path

  eb_application_name = module.eb.application_name
  eb_environment_name = module.eb.environment_name

  tags = local.tags

  depends_on = [module.eb]
}
