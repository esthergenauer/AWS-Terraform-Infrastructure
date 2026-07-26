output "application_name" {
  value = aws_elastic_beanstalk_application.this.name
}

output "environment_name" {
  value = aws_elastic_beanstalk_environment.this.name
}

output "environment_endpoint" {
  value = aws_elastic_beanstalk_environment.this.cname
}

output "service_role_arn" {
  description = "IAM role assumed by Elastic Beanstalk / CloudFormation during deployments"
  value       = aws_iam_role.service.arn
}

output "service_role_name" {
  value = aws_iam_role.service.name
}
