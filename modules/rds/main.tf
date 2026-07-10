locals {
  postgres_family = "postgres${split(".", var.engine_version)[0]}"
}

resource "aws_db_parameter_group" "this" {
  name        = "${var.name}-pg"
  family      = local.postgres_family
  description = "PostgreSQL parameters for ${var.name}"

  parameter {
    name  = "rds.force_ssl"
    value = "1"
  }

  tags = merge(var.tags, { Name = "${var.name}-pg" })
}

resource "aws_db_subnet_group" "this" {
  name       = "${var.name}-subnet-group"
  subnet_ids = var.subnet_ids

  tags = merge(var.tags, { Name = "${var.name}-subnet-group" })
}

resource "aws_security_group" "db_sg" {
  name        = "db-sg"
  description = "PostgreSQL access from Beanstalk and optional bastion only"
  vpc_id      = var.vpc_id

  ingress {
    description     = "PostgreSQL from Elastic Beanstalk"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.eb_security_group_id]
  }

  dynamic "ingress" {
    for_each = var.bastion_security_group_id != null ? [1] : []
    content {
      description     = "PostgreSQL from Bastion (Dev local access)"
      from_port       = 5432
      to_port         = 5432
      protocol        = "tcp"
      security_groups = [var.bastion_security_group_id]
    }
  }

  dynamic "ingress" {
    for_each = var.developer_access_cidr_blocks
    content {
      description = "PostgreSQL from developer IP"
      from_port   = 5432
      to_port     = 5432
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "db-sg" })
}

resource "aws_db_instance" "this" {
  identifier     = var.name
  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage > 0 ? var.max_allocated_storage : null

  db_name  = var.db_name
  username = var.username
  password = local.master_password
  port     = 5432

  db_subnet_group_name   = aws_db_subnet_group.this.name
  parameter_group_name   = aws_db_parameter_group.this.name
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  publicly_accessible    = var.publicly_accessible

  multi_az                = var.multi_az
  backup_retention_period = var.backup_retention_period
  storage_encrypted       = var.storage_encrypted
  skip_final_snapshot     = var.skip_final_snapshot

  tags = merge(var.tags, { Name = var.name })

  lifecycle {
    # Never rotate RDS password via Terraform on existing databases.
    ignore_changes = [password]
    prevent_destroy = true
  }
}
