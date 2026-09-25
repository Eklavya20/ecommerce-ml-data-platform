provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      project     = var.project_name
      environment = "bootstrap"
      managed_by  = "terraform"
    }
  }
}
