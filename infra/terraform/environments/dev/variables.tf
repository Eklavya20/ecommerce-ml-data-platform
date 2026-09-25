variable "aws_region" {
  description = "AWS region for the development environment."
  type        = string
  default     = "eu-central-1"
}

variable "project_name" {
  description = "Project name used in resource names and tags."
  type        = string
  default     = "ecommerce-ml-data-platform"
}

variable "environment" {
  description = "Environment name used in resource names and tags."
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "IPv4 CIDR for the development VPC."
  type        = string
  default     = "10.42.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid IPv4 CIDR."
  }
}

variable "public_subnet_cidrs" {
  description = "Two subnet CIDRs used for the RDS subnet group in separate availability zones."
  type        = list(string)
  default     = ["10.42.10.0/24", "10.42.20.0/24"]

  validation {
    condition = (
      length(var.public_subnet_cidrs) == 2 &&
      length(distinct(var.public_subnet_cidrs)) == 2 &&
      alltrue([for cidr in var.public_subnet_cidrs : can(cidrhost(cidr, 0))])
    )
    error_message = "public_subnet_cidrs must contain exactly two distinct valid IPv4 CIDRs."
  }
}

variable "allowed_cidr" {
  description = "Single public IPv4 address in /32 form permitted to connect to PostgreSQL."
  type        = string

  validation {
    condition = (
      can(cidrhost(var.allowed_cidr, 0)) &&
      endswith(var.allowed_cidr, "/32") &&
      var.allowed_cidr != "0.0.0.0/0"
    )
    error_message = "allowed_cidr must be one IPv4 /32 address and must never be 0.0.0.0/0."
  }
}

variable "db_name" {
  description = "Initial PostgreSQL database name."
  type        = string
  default     = "ecommerce"

  validation {
    condition     = can(regex("^[A-Za-z][A-Za-z0-9_]{0,62}$", var.db_name))
    error_message = "db_name must start with a letter and contain at most 63 letters, digits, or underscores."
  }
}

variable "db_username" {
  description = "RDS master username."
  type        = string
  default     = "ecommerce"

  validation {
    condition     = can(regex("^[A-Za-z][A-Za-z0-9_]{0,62}$", var.db_username))
    error_message = "db_username must start with a letter and contain at most 63 letters, digits, or underscores."
  }
}

variable "db_password" {
  description = "RDS master password. Supply through TF_VAR_db_password or an ignored terraform.tfvars file."
  type        = string
  sensitive   = true

  validation {
    condition = (
      length(var.db_password) >= 8 &&
      length(var.db_password) <= 128 &&
      length(regexall("[/\"@ ]", var.db_password)) == 0
    )
    error_message = "db_password must be 8-128 characters and cannot contain slash, double quote, at sign, or spaces."
  }
}

variable "db_instance_class" {
  description = "Small RDS instance class suitable for a temporary development environment."
  type        = string
  default     = "db.t4g.micro"
}

variable "db_allocated_storage_gib" {
  description = "Allocated encrypted RDS storage in GiB."
  type        = number
  default     = 20

  validation {
    condition     = var.db_allocated_storage_gib >= 20
    error_message = "db_allocated_storage_gib must be at least 20 GiB."
  }
}
