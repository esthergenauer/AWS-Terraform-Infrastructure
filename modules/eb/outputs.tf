output "application_name" {
  value = aws_elastic_beanstalk_application.this.name
}

output "environment_name" {
  value = aws_elastic_beanstalk_environment.this.name
}

output "environment_endpoint" {
  value = aws_elastic_beanstalk_environment.this.cname
}
