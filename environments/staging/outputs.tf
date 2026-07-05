output "vpc_id" {
  value = module.network.vpc_id
}

output "rds_endpoint" {
  value = module.rds.db_instance_endpoint
}

output "eb_url" {
  value = module.eb.environment_endpoint
}

output "bastion_instance_id" {
  description = "Use with SSM port forwarding for local DB access"
  value       = module.bastion.instance_id
}

output "pipeline_arn" {
  value = module.pipeline.pipeline_arn
}
