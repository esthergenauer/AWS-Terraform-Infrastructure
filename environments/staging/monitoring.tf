# =============================================================================
# Staging Observability — CloudWatch Alarms → SNS → Lambda → Slack
# =============================================================================
# ISOLATED FILE: Adds monitoring only. Does not modify RDS, pipeline, or bastion.
# EB ConfigDocument for metric publishing lives in modules/eb (safe option setting).
# =============================================================================

locals {
  monitoring_name_prefix = "${var.project_name}-staging"
  slack_secret_name      = "staging/slack-alerts-webhook"

  # Elastic Beanstalk EnvironmentHealth numeric scale (AWS docs):
  # 0=Ok, 1=Info, 5=Unknown, 10=NoData, 15=Warning, 20=Degraded, 25=Severe
  eb_health_alarm_threshold = 20

  eb_instance_id = try(data.aws_instances.eb_staging.ids[0], null)
  eb_asg_name    = try(data.aws_autoscaling_groups.eb_staging.names[0], null)
}

# ---------------------------------------------------------------------------
# Existing Slack webhook secret (created out-of-band — never hardcoded)
# ---------------------------------------------------------------------------
data "aws_secretsmanager_secret" "slack_alerts_webhook" {
  name = local.slack_secret_name
}

# Underlying EB instance(s) for StatusCheckFailed + RootFilesystemUtil (instance metrics)
data "aws_instances" "eb_staging" {
  filter {
    name   = "tag:elasticbeanstalk:environment-name"
    values = [module.eb.environment_name]
  }

  filter {
    name   = "instance-state-name"
    values = ["running", "pending", "stopping", "stopped"]
  }
}

data "aws_autoscaling_groups" "eb_staging" {
  filter {
    name   = "tag:elasticbeanstalk:environment-name"
    values = [module.eb.environment_name]
  }
}

# ---------------------------------------------------------------------------
# SNS topic — fan-out for all staging CloudWatch alarms
# ---------------------------------------------------------------------------
resource "aws_sns_topic" "staging_alerts" {
  name = "staging-alerts"

  tags = merge(local.tags, {
    Name    = "staging-alerts"
    Purpose = "cloudwatch-to-slack"
  })
}

# Explicit allow for CloudWatch Alarms to publish (same-account best practice)
resource "aws_sns_topic_policy" "staging_alerts" {
  arn = aws_sns_topic.staging_alerts.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowCloudWatchAlarmsPublish"
        Effect    = "Allow"
        Principal = { Service = "cloudwatch.amazonaws.com" }
        Action    = "sns:Publish"
        Resource  = aws_sns_topic.staging_alerts.arn
        Condition = {
          StringEquals = {
            "AWS:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })
}

resource "aws_sns_topic_subscription" "slack_lambda" {
  topic_arn = aws_sns_topic.staging_alerts.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.slack_alerts.arn
}

# ---------------------------------------------------------------------------
# IAM — dedicated Lambda execution role (least privilege)
# ---------------------------------------------------------------------------
resource "aws_iam_role" "slack_alerts_lambda" {
  name = "${local.monitoring_name_prefix}-slack-alerts-lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = merge(local.tags, { Name = "${local.monitoring_name_prefix}-slack-alerts-lambda" })
}

resource "aws_iam_role_policy_attachment" "slack_alerts_basic_logs" {
  role       = aws_iam_role.slack_alerts_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "slack_alerts_secret_read" {
  name = "${local.monitoring_name_prefix}-slack-webhook-secret-read"
  role = aws_iam_role.slack_alerts_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "GetSlackWebhookSecretOnly"
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = data.aws_secretsmanager_secret.slack_alerts_webhook.arn
    }]
  })
}

# ---------------------------------------------------------------------------
# Lambda — SNS → Slack translator (Python 3.12)
# ---------------------------------------------------------------------------
data "archive_file" "slack_alerts_lambda" {
  type        = "zip"
  source_file = "${path.module}/lambda/slack_alerts/handler.py"
  output_path = "${path.module}/lambda/slack_alerts/handler.zip"
}

# Create log group before the function to avoid a race on first invoke
resource "aws_cloudwatch_log_group" "slack_alerts_lambda" {
  name              = "/aws/lambda/${local.monitoring_name_prefix}-slack-alerts"
  retention_in_days = 14

  tags = merge(local.tags, { Name = "${local.monitoring_name_prefix}-slack-alerts-logs" })
}

resource "aws_lambda_function" "slack_alerts" {
  function_name = "${local.monitoring_name_prefix}-slack-alerts"
  description   = "Translates CloudWatch/SNS alarm events into Slack messages for staging"
  role          = aws_iam_role.slack_alerts_lambda.arn
  handler       = "handler.lambda_handler"
  runtime       = "python3.12"
  timeout       = 30
  memory_size   = 128

  filename         = data.archive_file.slack_alerts_lambda.output_path
  source_code_hash = data.archive_file.slack_alerts_lambda.output_base64sha256

  environment {
    variables = {
      SLACK_WEBHOOK_SECRET_NAME = local.slack_secret_name
      SLACK_WEBHOOK_SECRET_KEY  = "webhook_url"
    }
  }

  tags = merge(local.tags, { Name = "${local.monitoring_name_prefix}-slack-alerts" })

  depends_on = [
    aws_cloudwatch_log_group.slack_alerts_lambda,
    aws_iam_role_policy_attachment.slack_alerts_basic_logs,
    aws_iam_role_policy.slack_alerts_secret_read,
  ]
}

resource "aws_lambda_permission" "allow_sns_invoke" {
  statement_id  = "AllowSNSInvokeSlackAlerts"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.slack_alerts.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.staging_alerts.arn
}

# ---------------------------------------------------------------------------
# CloudWatch Alarms (core + recommended)
# ---------------------------------------------------------------------------

# Alarm 1 — High CPU load on the EB Auto Scaling Group (SingleInstance still has an ASG)
resource "aws_cloudwatch_metric_alarm" "eb_high_cpu" {
  count = local.eb_asg_name != null ? 1 : 0

  alarm_name          = "${local.monitoring_name_prefix}-eb-high-cpu"
  alarm_description   = "Staging EB CPU Utilization > 80% for 5 minutes"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  treat_missing_data  = "notBreaching"

  dimensions = {
    AutoScalingGroupName = local.eb_asg_name
  }

  alarm_actions = [aws_sns_topic.staging_alerts.arn]
  ok_actions    = [aws_sns_topic.staging_alerts.arn]

  tags = merge(local.tags, { Name = "${local.monitoring_name_prefix}-eb-high-cpu" })
}

# Alarm 2 — Application HTTP 5xx errors (EB environment metric; works without ALB)
resource "aws_cloudwatch_metric_alarm" "eb_http_5xx" {
  alarm_name          = "${local.monitoring_name_prefix}-eb-http-5xx"
  alarm_description   = "Staging EB ApplicationRequests5xx > 5 in a 5-minute window"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApplicationRequests5xx"
  namespace           = "AWS/ElasticBeanstalk"
  period              = 300
  statistic           = "Sum"
  threshold           = 5
  treat_missing_data  = "notBreaching"

  dimensions = {
    EnvironmentName = module.eb.environment_name
  }

  alarm_actions = [aws_sns_topic.staging_alerts.arn]
  ok_actions    = [aws_sns_topic.staging_alerts.arn]

  tags = merge(local.tags, { Name = "${local.monitoring_name_prefix}-eb-http-5xx" })
}

# Alarm 3 — EC2 instance status check failed (hardware / reachability crash)
resource "aws_cloudwatch_metric_alarm" "eb_status_check_failed" {
  count = local.eb_instance_id != null ? 1 : 0

  alarm_name          = "${local.monitoring_name_prefix}-eb-status-check-failed"
  alarm_description   = "Staging EB EC2 StatusCheckFailed > 0 (instance unhealthy / unreachable)"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "StatusCheckFailed"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Maximum"
  threshold           = 0
  treat_missing_data  = "breaching"

  dimensions = {
    InstanceId = local.eb_instance_id
  }

  alarm_actions = [aws_sns_topic.staging_alerts.arn]
  ok_actions    = [aws_sns_topic.staging_alerts.arn]

  tags = merge(local.tags, { Name = "${local.monitoring_name_prefix}-eb-status-check-failed" })
}

# Alarm 4 — Elastic Beanstalk environment health degraded / severe (Red / Unhealthy)
resource "aws_cloudwatch_metric_alarm" "eb_environment_health" {
  alarm_name          = "${local.monitoring_name_prefix}-eb-environment-health"
  alarm_description   = "Staging EB EnvironmentHealth >= Degraded (20) — Red/Unhealthy territory"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "EnvironmentHealth"
  namespace           = "AWS/ElasticBeanstalk"
  period              = 60
  statistic           = "Average"
  threshold           = local.eb_health_alarm_threshold
  treat_missing_data  = "breaching"

  dimensions = {
    EnvironmentName = module.eb.environment_name
  }

  alarm_actions = [aws_sns_topic.staging_alerts.arn]
  ok_actions    = [aws_sns_topic.staging_alerts.arn]

  tags = merge(local.tags, { Name = "${local.monitoring_name_prefix}-eb-environment-health" })
}

# ---------------------------------------------------------------------------
# Recommended extras — prevent silent disk / DB failures
# ---------------------------------------------------------------------------

# Alarm 5 — Root filesystem utilization (INSTANCE metric — requires InstanceId)
resource "aws_cloudwatch_metric_alarm" "eb_root_filesystem" {
  count = local.eb_instance_id != null ? 1 : 0

  alarm_name          = "${local.monitoring_name_prefix}-eb-root-disk-high"
  alarm_description   = "Staging EB RootFilesystemUtil > 85% for 5 minutes (disk pressure)"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "RootFilesystemUtil"
  namespace           = "AWS/ElasticBeanstalk"
  period              = 300
  statistic           = "Average"
  threshold           = 85
  treat_missing_data  = "notBreaching"

  dimensions = {
    EnvironmentName = module.eb.environment_name
    InstanceId      = local.eb_instance_id
  }

  alarm_actions = [aws_sns_topic.staging_alerts.arn]
  ok_actions    = [aws_sns_topic.staging_alerts.arn]

  tags = merge(local.tags, { Name = "${local.monitoring_name_prefix}-eb-root-disk-high" })
}

# Alarm 6 — RDS free storage critically low (prevents write failures / downtime)
resource "aws_cloudwatch_metric_alarm" "rds_low_storage" {
  alarm_name          = "${local.monitoring_name_prefix}-rds-low-storage"
  alarm_description   = "Staging RDS FreeStorageSpace < 2 GiB (database disk pressure)"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 2147483648 # 2 GiB in bytes
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBInstanceIdentifier = var.rds_name
  }

  alarm_actions = [aws_sns_topic.staging_alerts.arn]
  ok_actions    = [aws_sns_topic.staging_alerts.arn]

  tags = merge(local.tags, { Name = "${local.monitoring_name_prefix}-rds-low-storage" })
}
