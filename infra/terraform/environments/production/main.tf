# Production: three cells.
#
# Apply order: us-east-1 → eu-west-1 → ap-southeast-1.
# Each apply is idempotent and uses a separate state file (S3 backend).

terraform {
  required_version = ">= 1.7"

  backend "s3" {
    bucket         = "velix-tfstate-prod"
    key            = "production/cells.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "velix-tfstate-locks"
  }
}

provider "aws" {
  alias  = "us"
  region = "us-east-1"
}

provider "aws" {
  alias  = "eu"
  region = "eu-west-1"
}

provider "aws" {
  alias  = "ap"
  region = "ap-southeast-1"
}

module "cell_us" {
  source    = "../../modules/velix-cell"
  providers = { aws = aws.us }

  cell_name               = "us-east-1"
  region                  = "us-east-1"
  vpc_cidr                = "10.10.0.0/16"
  postgres_instance_class = "db.r6g.2xlarge"
  postgres_storage_gb     = 500
}

module "cell_eu" {
  source    = "../../modules/velix-cell"
  providers = { aws = aws.eu }

  cell_name = "eu-west-1"
  region    = "eu-west-1"
  vpc_cidr  = "10.20.0.0/16"
}

module "cell_ap" {
  source    = "../../modules/velix-cell"
  providers = { aws = aws.ap }

  cell_name = "ap-southeast-1"
  region    = "ap-southeast-1"
  vpc_cidr  = "10.30.0.0/16"
}

output "cells" {
  value = {
    us = module.cell_us.cell_name
    eu = module.cell_eu.cell_name
    ap = module.cell_ap.cell_name
  }
}
