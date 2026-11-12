# Pathways in a VPC your network team already runs, found by its tags rather than by ids pasted in,
# with each tier in its own subnets: the engine in the private application subnets, the database in
# the database subnets, and the internal load balancer in the subnets your network routes partner
# traffic to. This example creates no network: no VPC, no subnet, no route and no NAT gateway.
#
# The tags are placeholders for your own: a VPC tagged Name = var.vpc_name, and subnets in it tagged
# Tier = app, data and edge. Every other value is a placeholder too: the account id 123456789012,
# the image digest and the secret ARN.

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project = "pathways-byo-vpc"
    }
  }
}

data "aws_vpc" "this" {
  tags = {
    Name = var.vpc_name
  }
}

data "aws_subnets" "app" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.this.id]
  }
  tags = {
    Tier = var.app_subnet_tier
  }
}

data "aws_subnets" "data" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.this.id]
  }
  tags = {
    Tier = var.data_subnet_tier
  }
}

data "aws_subnets" "edge" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.this.id]
  }
  tags = {
    Tier = var.edge_subnet_tier
  }
}

module "pathways" {
  source = "../.."

  name   = "byo-vpc"
  vpc_id = data.aws_vpc.this.id

  # Each tier in its own subnets. Sorted, so the order AWS returns them in does not change the plan.
  private_subnet_ids       = sort(data.aws_subnets.app.ids)
  database_subnet_ids      = sort(data.aws_subnets.data.ids)
  load_balancer_subnet_ids = sort(data.aws_subnets.edge.ids)

  # The load balancer stays internal (the module's default): your network brings partners to it.
  load_balancer_internal = true
  allowed_cidr_blocks    = var.allowed_cidr_blocks

  image = var.image

  mllp_sources = {
    adt = { port = 2575 }
  }
  probe_port = 9091

  egress_rules = {
    https = {
      port        = 443
      cidr_blocks = ["0.0.0.0/0"]
    }
    lab = {
      port        = 2576
      cidr_blocks = var.lab_cidr_blocks
    }
  }

  environment = {
    PATHWAYS_STORAGE = "postgres"
  }
  secrets = {
    PATHWAYS_KEY_2026_11 = var.master_key_secret_arn
  }
}
