# =============================================================================
# Grafana Cloud — Cross-account IAM for CloudWatch metrics (read-only)
# =============================================================================
# ISOLATED FILE: Adds Grafana Cloud AssumeRole access only.
# Does not modify RDS, EB, pipeline, bastion, or monitoring alarms.
#
# Security: grafana_cloud_external_id is NEVER stored in .tfvars.
# Inject at apply time via environment variable:
#   export TF_VAR_grafana_cloud_external_id="<from-grafana-cloud-ui>"
#
# After apply, paste the output ARN into Grafana Cloud → AWS → CloudWatch:
#   terraform output -raw grafana_cloud_iam_role_arn
# =============================================================================

locals {
  grafana_iam_name_prefix = "${var.project_name}-staging-grafana-cloud"
}

resource "aws_iam_role" "grafana_cloud" {
  name        = local.grafana_iam_name_prefix
  description = "Cross-account role for Grafana Cloud to read CloudWatch metrics (staging)"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowGrafanaCloudAssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.grafana_cloud_aws_account_id}:root"
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "sts:ExternalId" = var.grafana_cloud_external_id
          }
        }
      }
    ]
  })

  tags = merge(local.tags, {
    Name    = local.grafana_iam_name_prefix
    Purpose = "grafana-cloud-cloudwatch"
  })
}

resource "aws_iam_policy" "grafana_cloud_metrics" {
  name        = "${local.grafana_iam_name_prefix}-metrics"
  description = "Minimal CloudWatch metrics + Logs read permissions for Grafana Cloud"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowGrafanaCloudWatchRead"
        Effect = "Allow"
        Action = [
          "cloudwatch:GetMetricData",
          "cloudwatch:ListMetrics",
          "tag:GetResources",
          "logs:DescribeLogGroups",
          "logs:GetLogEvents",
          "logs:FilterLogEvents"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(local.tags, {
    Name    = "${local.grafana_iam_name_prefix}-metrics"
    Purpose = "grafana-cloud-cloudwatch"
  })
}

resource "aws_iam_role_policy_attachment" "grafana_cloud_metrics" {
  role       = aws_iam_role.grafana_cloud.name
  policy_arn = aws_iam_policy.grafana_cloud_metrics.arn
}
