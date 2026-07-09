resource "random_password" "db_master" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

locals {
  # Existing environments: pass db_password in tfvars (same value as today).
  # New environments: omit db_password and Terraform generates one automatically.
  master_password = coalesce(var.password, random_password.db_master.result)
}

resource "aws_secretsmanager_secret" "db_credentials" {
  name                    = "${var.name}/db-credentials"
  description             = "PostgreSQL credentials for ${var.name}"
  recovery_window_in_days = var.environment == "prod" ? 30 : 0

  tags = merge(var.tags, { Name = "${var.name}-db-credentials" })
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id

  secret_string = jsonencode({
    username = var.username
    password = local.master_password
    engine   = "postgres"
    host     = aws_db_instance.this.address
    port     = aws_db_instance.this.port
    dbname   = var.db_name
  })

  lifecycle {
    # Do not overwrite secret payload on later applies (safe for manual rotation).
    ignore_changes = [secret_string]
  }
}
