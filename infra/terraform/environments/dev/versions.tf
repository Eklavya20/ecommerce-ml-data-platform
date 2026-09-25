terraform {
  required_version = "~> 1.16.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.61.0"
    }
  }

  backend "s3" {
    key          = "ecommerce-ml-data-platform/dev/terraform.tfstate"
    encrypt      = true
    use_lockfile = true
  }
}
