# Velix cell module.
#
# A "cell" is the failure domain. We deploy three cells (us-east-1,
# eu-west-1, ap-southeast-1). Each cell is operationally independent:
# its own VPC, EKS cluster, Postgres, NATS, Redis, Vault namespace, R2
# region partition, and IAM scope.
#
# See docs/phase-10/02-deployment-topology.md.

terraform {
  required_version = ">= 1.7"
  required_providers {
    aws        = { source = "hashicorp/aws", version = "~> 5.40" }
    kubernetes = { source = "hashicorp/kubernetes", version = "~> 2.27" }
    helm       = { source = "hashicorp/helm", version = "~> 2.13" }
  }
}

variable "cell_name" {
  type        = string
  description = "Cell identifier (e.g., us-east-1, eu-west-1, ap-southeast-1)."
}

variable "region" {
  type        = string
  description = "AWS region for this cell."
}

variable "vpc_cidr" {
  type        = string
  description = "VPC CIDR block."
}

variable "kubernetes_version" {
  type    = string
  default = "1.30"
}

variable "node_instance_types" {
  type    = list(string)
  default = ["m6i.xlarge", "m6i.2xlarge"]
}

variable "node_min_size" {
  type    = number
  default = 6
}

variable "node_max_size" {
  type    = number
  default = 60
}

variable "postgres_instance_class" {
  type    = string
  default = "db.r6g.xlarge"
}

variable "postgres_storage_gb" {
  type    = number
  default = 200
}

# ---------------------------------------------------------------------------
# Outputs are the integration seam: Argo CD, app-config, and DR runbooks
# read these.
# ---------------------------------------------------------------------------

output "cell_name" {
  value = var.cell_name
}

output "region" {
  value = var.region
}

output "kubeconfig_command" {
  value = "aws eks update-kubeconfig --name velix-${var.cell_name} --region ${var.region}"
}

output "vpc_id" {
  value = aws_vpc.this.id
}

output "subnet_ids" {
  value = aws_subnet.private[*].id
}

# ---------------------------------------------------------------------------
# Networking — VPC + private subnets + NAT.
# ---------------------------------------------------------------------------

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name        = "velix-${var.cell_name}"
    Environment = "production"
    Cell        = var.cell_name
  }
}

data "aws_availability_zones" "this" {
  state = "available"
}

locals {
  azs           = slice(data.aws_availability_zones.this.names, 0, 3)
  private_cidrs = [for i, _ in local.azs : cidrsubnet(var.vpc_cidr, 4, i)]
  public_cidrs  = [for i, _ in local.azs : cidrsubnet(var.vpc_cidr, 4, i + 8)]
}

resource "aws_subnet" "private" {
  count             = length(local.azs)
  vpc_id            = aws_vpc.this.id
  cidr_block        = local.private_cidrs[count.index]
  availability_zone = local.azs[count.index]
  tags = {
    Name                              = "velix-${var.cell_name}-private-${count.index}"
    "kubernetes.io/role/internal-elb" = "1"
  }
}

resource "aws_subnet" "public" {
  count                   = length(local.azs)
  vpc_id                  = aws_vpc.this.id
  cidr_block              = local.public_cidrs[count.index]
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = true
  tags = {
    Name                     = "velix-${var.cell_name}-public-${count.index}"
    "kubernetes.io/role/elb" = "1"
  }
}

# (NAT, route tables, IGW, EKS cluster, RDS Postgres, ElastiCache Redis,
# NATS JetStream NLB, KMS keys, Vault namespace bootstrap follow in the
# expanded module — these are tracked in docs/phase-10/02 and provisioned
# during Sprint 1 of the launch run-up.)
