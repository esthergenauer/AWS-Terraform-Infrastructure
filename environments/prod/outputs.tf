output "vpc_id" {
  value = data.aws_vpc.default.id
}

output "rds_endpoint" {
  value = module.rds.db_instance_endpoint
}

output "eb_url" {
  value = module.eb.environment_endpoint
}

output "pipeline_arn" {
  value = module.pipeline.pipeline_arn
}
