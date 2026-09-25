variable "aws_region" {
  description = "AWS region in which the Terraform state bucket is created."
  type        = string
  default     = "eu-central-1"
}

variable "project_name" {
  description = "Project tag applied to bootstrap resources."
  type        = string
  default     = "ecommerce-ml-data-platform"
}

variable "state_bucket_name" {
  description = "Globally unique S3 bucket name for Terraform state."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.state_bucket_name))
    error_message = "state_bucket_name must be a valid lowercase S3 bucket name between 3 and 63 characters."
  }
}

variable "state_bucket_force_destroy" {
  description = "Allow Terraform to delete a non-empty state bucket. Keep false until all environment state is no longer needed."
  type        = bool
  default     = false
}
