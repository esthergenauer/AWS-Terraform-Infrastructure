output "vpc_id" {
  value = data.aws_vpc.default.id
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

output "dev_tunnel_iam_user" {
  description = "Shared IAM user for developer SSM tunnel — create access key in AWS Console"
  value       = aws_iam_user.dev_tunnel.name
}

output "pipeline_arn" {
  value = module.pipeline.pipeline_arn
}
