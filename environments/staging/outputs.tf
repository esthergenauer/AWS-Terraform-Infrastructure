output "vpc_id" {
  value = data.aws_vpc.default.id
}

output "rds_endpoint" {
  value = module.rds.db_instance_endpoint
}

output "db_secret_arn" {
  description = "RDS credentials secret — use DB_SECRET_ARN in the application"
  value       = module.rds.db_secret_arn
}

output "eb_url" {
  value = module.eb.environment_endpoint
}

output "developer_urls" {
  description = "Share with developers for cloud testing (no local setup required)"
  value = {
    environment_label = "DEV (Staging)"
    server_health     = "http://${module.eb.environment_endpoint}/health"
    api_health        = "http://${module.eb.environment_endpoint}/api/health"
    web_client        = "http://${module.eb.environment_endpoint}/"
    backend_repo      = var.pipeline_source_repo
    backend_branch    = var.pipeline_source_branch
    frontend_repo     = var.pipeline_frontend_repo
    frontend_branch   = var.pipeline_frontend_branch
    deploy_trigger    = "Auto — push/merge to backend branch '${var.pipeline_source_branch}' runs CodePipeline"
    frontend_in_build = "Auto — CodeBuild clones frontend branch '${var.pipeline_frontend_branch}' on every deploy"
  }
}

output "bastion_instance_id" {
  description = "Use with SSM port forwarding for local DB access"
  value       = module.bastion.instance_id
}

output "dev_tunnel_iam_user" {
  description = "Shared IAM user for developer SSM tunnel — create access key in AWS Console"
  value       = aws_iam_user.dev_tunnel.name
}

output "pipeline_arn" {
  value = module.pipeline.pipeline_arn
}

output "pipeline_name" {
  value = var.pipeline_name
}

# --- Observability (see monitoring.tf) ---
output "staging_alerts_sns_topic_arn" {
  description = "SNS topic that receives all staging CloudWatch alarms"
  value       = aws_sns_topic.staging_alerts.arn
}

output "slack_alerts_lambda_name" {
  description = "Lambda that posts CloudWatch alarms to Slack"
  value       = aws_lambda_function.slack_alerts.function_name
}

output "monitoring_alarm_names" {
  description = "CloudWatch alarm names provisioned for staging"
  value = compact([
    try(aws_cloudwatch_metric_alarm.eb_high_cpu[0].alarm_name, null),
    aws_cloudwatch_metric_alarm.eb_http_5xx.alarm_name,
    try(aws_cloudwatch_metric_alarm.eb_status_check_failed[0].alarm_name, null),
    aws_cloudwatch_metric_alarm.eb_environment_health.alarm_name,
    try(aws_cloudwatch_metric_alarm.eb_root_filesystem[0].alarm_name, null),
    aws_cloudwatch_metric_alarm.rds_low_storage.alarm_name,
  ])
}
