output "db_instance_endpoint" {
  value = aws_db_instance.this.endpoint
}

output "db_instance_address" {
  value = aws_db_instance.this.address
}

output "db_instance_arn" {
  value = aws_db_instance.this.arn
}

output "security_group_id" {
  value = aws_security_group.db_sg.id
}

output "db_port" {
  value = aws_db_instance.this.port
}
