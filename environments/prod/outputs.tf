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

output "pipeline_arn" {
  value = module.pipeline.pipeline_arn
}
