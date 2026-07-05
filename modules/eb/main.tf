locals {
  base_env_vars = {
    DB_HOST     = var.db_host
    DB_NAME     = var.db_name
    DB_USER     = var.db_user
    DB_PASSWORD = var.db_password
  }

  environment_variables = merge(local.base_env_vars, var.additional_environment_variables)
}

resource "aws_elastic_beanstalk_application" "this" {
  name        = var.application_name
  description = var.description

  tags = merge(var.tags, { Name = var.application_name })
}

resource "aws_elastic_beanstalk_environment" "this" {
  name                = var.environment_name
  application         = aws_elastic_beanstalk_application.this.name
  solution_stack_name = var.solution_stack_name
  tier                = "WebServer"

  setting {
    namespace = "aws:ec2:vpc"
    name      = "VPCId"
    value     = var.vpc_id
  }

  setting {
    namespace = "aws:ec2:vpc"
    name      = "Subnets"
    value     = join(",", var.instance_subnet_ids)
  }

  setting {
    namespace = "aws:ec2:vpc"
    name      = "AssociatePublicIpAddress"
    value     = var.associate_public_ip_address ? "true" : "false"
  }

  dynamic "setting" {
    for_each = var.environment_type == "LoadBalanced" ? [1] : []
    content {
      namespace = "aws:ec2:vpc"
      name      = "ELBSubnets"
      value     = join(",", var.elb_subnet_ids)
    }
  }

  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "InstanceType"
    value     = var.instance_type
  }

  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "SecurityGroups"
    value     = var.security_group_id
  }

  setting {
    namespace = "aws:autoscaling:asg"
    name      = "MinSize"
    value     = tostring(var.min_instances)
  }

  setting {
    namespace = "aws:autoscaling:asg"
    name      = "MaxSize"
    value     = tostring(var.max_instances)
  }

  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "EnvironmentType"
    value     = var.environment_type
  }

  dynamic "setting" {
    for_each = var.environment_type == "LoadBalanced" ? [1] : []
    content {
      namespace = "aws:elasticbeanstalk:environment"
      name      = "LoadBalancerType"
      value     = var.load_balancer_type
    }
  }

  dynamic "setting" {
    for_each = local.environment_variables
    content {
      namespace = "aws:elasticbeanstalk:application:environment"
      name      = setting.key
      value     = setting.value
    }
  }

  tags = merge(var.tags, { Name = var.environment_name })
}
