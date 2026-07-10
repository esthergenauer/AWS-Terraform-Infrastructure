locals {
  base_env_vars = merge(
    {
      DB_HOST       = var.db_host
      DB_NAME       = var.db_name
      DB_USER       = var.db_user
      DB_SECRET_ARN = var.db_secret_arn
      DB_PORT       = "5432"
    },
    var.db_password != null ? { DB_PASSWORD = var.db_password } : {}
  )

  environment_variables = merge(local.base_env_vars, var.additional_environment_variables)

  # AWS only accepts period=60 for enhanced-health CloudWatch publishing.
  # null = do not publish; 60 = publish every minute.
  # Keep this list focused on metrics we alarm on (cost-aware).
  health_config_document = jsonencode({
    Version = 1
    CloudWatchMetrics = {
      Environment = {
        ApplicationRequests5xx = 60
        ApplicationRequests4xx = 60
      }
      Instance = {
        RootFilesystemUtil = 60
      }
    }
  })
}

resource "aws_iam_role" "service" {
  name = "${var.environment_name}-eb-service-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "elasticbeanstalk.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = merge(var.tags, { Name = "${var.environment_name}-eb-service-role" })
}

resource "aws_iam_role_policy_attachment" "service_managed" {
  role       = aws_iam_role.service.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSElasticBeanstalkService"
}

resource "aws_iam_role_policy_attachment" "service_enhanced_health" {
  role       = aws_iam_role.service.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSElasticBeanstalkEnhancedHealth"
}

locals {
  pipeline_artifact_s3_resources = var.pipeline_artifact_bucket_name != null ? [
    "arn:aws:s3:::${var.pipeline_artifact_bucket_name}",
    "arn:aws:s3:::${var.pipeline_artifact_bucket_name}/*"
  ] : []

  service_s3_deploy_resources = concat(
    [
      "arn:aws:s3:::elasticbeanstalk-platform-assets-${var.aws_region}",
      "arn:aws:s3:::elasticbeanstalk-platform-assets-${var.aws_region}/*",
      "arn:aws:s3:::elasticbeanstalk-${var.aws_region}-${var.aws_account_id}",
      "arn:aws:s3:::elasticbeanstalk-${var.aws_region}-${var.aws_account_id}/*"
    ],
    local.pipeline_artifact_s3_resources
  )
}

resource "aws_iam_role_policy" "service_s3_deploy" {
  name = "${var.environment_name}-eb-service-s3-deploy"
  role = aws_iam_role.service.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:ListBucket"
        ]
        Resource = local.service_s3_deploy_resources
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "kms:ViaService" = "s3.${var.aws_region}.amazonaws.com"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role" "ec2" {
  name = "${var.environment_name}-eb-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "eb_web_tier" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AWSElasticBeanstalkWebTier"
}

resource "aws_iam_role_policy_attachment" "eb_worker_tier" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AWSElasticBeanstalkWorkerTier"
}

resource "aws_iam_role_policy_attachment" "eb_multicontainer_docker" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AWSElasticBeanstalkMulticontainerDocker"
}

resource "aws_iam_role_policy" "eb_read_db_secret" {
  name = "${var.environment_name}-read-db-secret"
  role = aws_iam_role.ec2.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = var.db_secret_arn
    }]
  })
}

resource "aws_iam_instance_profile" "ec2" {
  name = "${var.environment_name}-eb-ec2-profile"
  role = aws_iam_role.ec2.name

  tags = var.tags
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
    name      = "IamInstanceProfile"
    value     = aws_iam_instance_profile.ec2.name
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

  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "ServiceRole"
    value     = aws_iam_role.service.name
  }

  # Enhanced health reporting (already typical on modern platforms; set explicitly).
  setting {
    namespace = "aws:elasticbeanstalk:healthreporting:system"
    name      = "SystemType"
    value     = "enhanced"
  }

  # Publish selected enhanced-health metrics to CloudWatch so alarms receive data.
  # Safe config-only update: does not replace instances or rotate credentials.
  dynamic "setting" {
    for_each = var.publish_enhanced_health_metrics ? [1] : []
    content {
      namespace = "aws:elasticbeanstalk:healthreporting:system"
      name      = "ConfigDocument"
      value     = local.health_config_document
    }
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
