# Terraform state bootstrap

This independent Terraform root creates the S3 bucket used by the development environment's remote backend. It intentionally uses local state: an S3 backend cannot store its own state until the bucket exists.

## Prerequisites

- Terraform `1.16.x`
- AWS credentials supplied through an AWS profile, IAM role, IAM Identity Center, or standard AWS environment variables
- IAM permissions to create and configure the state bucket

Never place AWS credentials in Terraform files or committed variable files.

## Create the backend bucket

```bash
cd infra/terraform/bootstrap
cp terraform.tfvars.example terraform.tfvars
# Replace state_bucket_name with a globally unique bucket name.

terraform init
terraform fmt -check
terraform validate
terraform plan -out=bootstrap.tfplan
terraform apply bootstrap.tfplan
terraform output -raw state_bucket_name
```

The bucket has versioning, AES-256 server-side encryption, public-access blocking, bucket-owner-enforced object ownership, and a policy requiring TLS. The development backend uses an S3 lockfile; no DynamoDB table is required.

Keep this bootstrap state secure and backed up. Do not destroy the bucket while an environment still relies on its state. To remove it after destroying every dependent environment, set `state_bucket_force_destroy = true`, review a plan, and run:

```bash
terraform destroy
```

S3 storage and requests may incur charges. State is normally small, but versioned objects remain until explicitly removed or the bucket is destroyed with `force_destroy` enabled.
