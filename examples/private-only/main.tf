# Private only: nothing is reachable from the internet, and nothing reaches out to it. The VPC has no
# internet gateway route and no NAT gateway in the engine's subnets; the engine reaches the AWS APIs
# it needs through VPC endpoints this example creates, and its HTTPS egress goes to the VPC's own
# network and to S3's gateway endpoint alone, not to 0.0.0.0/0. The network load balancer is
# internal, the tasks get no public address, and the database is not publicly accessible: the
# module's defaults, written out here.
#
# Every value here is a placeholder: the VPC, subnet and route table ids, the account id
# 123456789012, the image digest and the secret ARN. Put your own in before you plan.

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project = "pathways-private"
    }
  }
}

data "aws_vpc" "this" {
  id = var.vpc_id
}

module "pathways" {
  source = "../.."

  name   = "private"
  vpc_id = var.vpc_id

  private_subnet_ids  = var.private_subnet_ids
  allowed_cidr_blocks = var.allowed_cidr_blocks

  # Internal: the load balancer gets private addresses only (the module's default).
  load_balancer_internal = true

  image = var.image

  mllp_sources = {
    adt = { port = 2575 }
  }
  probe_port = 9091

  # HTTPS to the VPC's own network only, where the interface endpoints below listen, and the lab's
  # MLLP port. S3, for the image's layers, is the rule beside the module call. No rule reaches the
  # internet.
  egress_rules = {
    endpoints = {
      port        = 443
      cidr_blocks = [data.aws_vpc.this.cidr_block]
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

# ---------------------------------------------------------------------------
# VPC endpoints: what a Fargate task needs with no NAT gateway
# ---------------------------------------------------------------------------

locals {
  # Pull the image (ecr.api and ecr.dkr, with its layers from S3), read the secrets
  # (secretsmanager) and write the logs (logs).
  interface_endpoints = toset(["ecr.api", "ecr.dkr", "secretsmanager", "logs"])
}

resource "aws_security_group" "endpoints" {
  name        = "pathways-private-endpoints"
  description = "Pathways private: the VPC interface endpoints, reachable from the engine only"
  vpc_id      = var.vpc_id
}

resource "aws_vpc_security_group_ingress_rule" "endpoints_from_engine" {
  security_group_id            = aws_security_group.endpoints.id
  description                  = "HTTPS from the engine"
  referenced_security_group_id = module.pathways.engine_security_group_id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
}

resource "aws_vpc_endpoint" "interface" {
  for_each = local.interface_endpoints

  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.region}.${each.key}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [aws_security_group.endpoints.id]
  private_dns_enabled = true

  tags = {
    Name = "pathways-private-${each.key}"
  }
}

# S3 is a gateway endpoint: a route in the subnets' route tables, at no hourly charge. ECR serves
# image layers from S3.
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = var.private_route_table_ids

  tags = {
    Name = "pathways-private-s3"
  }
}

resource "aws_vpc_security_group_egress_rule" "engine_to_s3" {
  security_group_id = module.pathways.engine_security_group_id
  description       = "HTTPS to S3, through the gateway endpoint"
  prefix_list_id    = aws_vpc_endpoint.s3.prefix_list_id
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}
