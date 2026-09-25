resource "aws_security_group" "database" {
  name        = "${local.name_prefix}-postgres"
  description = "PostgreSQL access from one developer IPv4 address"
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "PostgreSQL from configured developer address"
    protocol    = "tcp"
    from_port   = 5432
    to_port     = 5432
    cidr_blocks = [var.allowed_cidr]
  }

  egress {
    description = "Allow RDS outbound traffic"
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.name_prefix}-postgres-sg"
  }
}
