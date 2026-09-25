resource "aws_db_instance" "postgres" {
  identifier = local.name_prefix

  engine         = "postgres"
  engine_version = "16"
  instance_class = var.db_instance_class

  allocated_storage = var.db_allocated_storage_gib
  storage_type      = "gp3"
  storage_encrypted = true

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password
  port     = 5432

  db_subnet_group_name   = aws_db_subnet_group.database.name
  vpc_security_group_ids = [aws_security_group.database.id]
  publicly_accessible    = true
  multi_az               = false

  backup_retention_period    = 1
  deletion_protection        = false
  skip_final_snapshot        = true
  apply_immediately          = true
  auto_minor_version_upgrade = true

  iam_database_authentication_enabled = false
  performance_insights_enabled        = false

  tags = {
    Name = local.name_prefix
  }
}
