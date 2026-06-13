# Staging: single cell in us-east-1. Mirror of production at smaller scale.

terraform {
  required_version = ">= 1.7"
  backend "s3" {
    bucket         = "velix-tfstate-staging"
    key            = "staging/cell.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "velix-tfstate-locks-staging"
  }
}

provider "aws" {
  region = "us-east-1"
}

module "cell_staging" {
  source = "../../modules/velix-cell"

  cell_name               = "staging"
  region                  = "us-east-1"
  vpc_cidr                = "10.99.0.0/16"
  node_min_size           = 3
  node_max_size           = 12
  postgres_instance_class = "db.r6g.large"
  postgres_storage_gb     = 100
}
