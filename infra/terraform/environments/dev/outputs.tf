output "vpc_id" {
  description = "Development VPC ID."
  value       = aws_vpc.this.id
}

output "subnet_ids" {
  description = "Subnet IDs in separate availability zones used by the DB subnet group."
  value       = aws_subnet.public[*].id
}

output "database_security_group_id" {
  description = "Security group restricting PostgreSQL ingress to allowed_cidr."
  value       = aws_security_group.database.id
}

output "rds_endpoint" {
  description = "RDS hostname without the port suffix."
  value       = aws_db_instance.postgres.address
}

output "rds_port" {
  description = "PostgreSQL listener port."
  value       = aws_db_instance.postgres.port
}

output "database_name" {
  description = "Initial PostgreSQL database name."
  value       = aws_db_instance.postgres.db_name
}

output "database_username" {
  description = "Non-secret PostgreSQL master username used by the pipeline."
  value       = aws_db_instance.postgres.username
}
