# AWS development environment

This Terraform root creates a deliberately small, disposable AWS environment for running the existing data generator, dbt project, and ML workflow against RDS PostgreSQL. Terraform creates infrastructure only; it never creates raw tables or dbt models.

## Resources and access model

- One VPC and internet gateway
- Two public-route subnets in separate availability zones
- One DB subnet group
- One security group allowing TCP 5432 only from `allowed_cidr`
- One encrypted, single-AZ PostgreSQL 16 RDS instance (`db.t4g.micro`, 20 GiB gp3 by default)

RDS is publicly reachable solely so dbt and Python can run from a developer workstation. The security group requires one configured public IPv4 `/32`; `0.0.0.0/0` is rejected. This is a temporary portfolio/dev tradeoff. A production design should use private database subnets, deletion protection, stronger backup/HA settings, managed secret rotation, and workloads running inside the VPC.

No NAT gateway, load balancer, compute service, or orchestration platform is created.

The deployment region is configurable through `aws_region`; `eu-central-1` is an example default only. AWS Organizations or project policies may restrict allowed regions. This repository was successfully validated in `eu-north-1`, including raw-data loading, dbt build, and ML training. The validation RDS environment was destroyed afterward.

## Initialize remote state

Create the bootstrap bucket first. Then run from this directory, substituting the bucket output:

```bash
cp terraform.tfvars.example terraform.tfvars
# Set allowed_cidr to your current public IPv4/32.
# Set aws_region to a region permitted by your AWS account.
# Leave db_password commented and use TF_VAR_db_password when possible.

export AWS_REGION="YOUR_AWS_REGION"

terraform init \
  -backend-config="bucket=YOUR_STATE_BUCKET" \
  -backend-config="region=$AWS_REGION"
terraform fmt -check
terraform validate
terraform plan -out=dev.tfplan
terraform apply dev.tfplan
```

The backend stores state at `ecommerce-ml-data-platform/dev/terraform.tfstate`, encrypts it, and uses an S3 `.tflock` object for state locking. AWS credentials come from the standard provider credential chain; they are never Terraform variables. State contains the sensitive RDS password even though no output exposes it, so restrict IAM access to the state object and its lockfile and treat state as secret-bearing data.

## Initialize and run the existing pipeline

From the repository root, configure the same environment variables used locally:

```bash
export DB_HOST="$(terraform -chdir=infra/terraform/environments/dev output -raw rds_endpoint)"
export DB_PORT="$(terraform -chdir=infra/terraform/environments/dev output -raw rds_port)"
export DB_NAME="$(terraform -chdir=infra/terraform/environments/dev output -raw database_name)"
export DB_USER="$(terraform -chdir=infra/terraform/environments/dev output -raw database_username)"
export DB_PASSWORD="YOUR_RDS_PASSWORD"
export DBT_SCHEMA="analytics"

export PGPASSWORD="$DB_PASSWORD"
psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" \
  -f docker/init/001_create_raw_schema.sql

python -m data_generator.generate_and_load --seed 42 --scale 20 --batch baseline
dbt source freshness --project-dir dbt --profiles-dir dbt
dbt build --full-refresh --project-dir dbt --profiles-dir dbt
python -m ml.train
```

The SQL file above is the same initialization used by Docker Compose. No schema or business logic is duplicated in Terraform.

## Cost and cleanup

RDS instance runtime and allocated storage incur charges. S3 state storage/requests and internet data transfer may also incur charges. Pricing and account credits vary; this configuration does not claim to be free.

Destroy the development environment immediately after testing:

```bash
cd infra/terraform/environments/dev
terraform destroy
```

Confirm that the RDS instance is gone in AWS. The state bucket is separate and remains until deliberately destroyed from the bootstrap directory.
