# Pathways on ECS Fargate with one MLLP source and one HTTP source, in an existing VPC.
#
# Every value here is a placeholder: the VPC and subnet ids, the account id 123456789012, the image
# digest and the secret ARN. Put your own in before you plan.

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project = "integration"
    }
  }
}

module "pathways" {
  source = "../.."

  name   = "integration"
  vpc_id = var.vpc_id

  private_subnet_ids  = var.private_subnet_ids
  allowed_cidr_blocks = var.allowed_cidr_blocks

  # Your project's own image, by digest.
  image = var.image

  cpu    = 1024
  memory = 2048

  mllp_sources = {
    adt = { port = 2575 }
  }
  http_sources = {
    orders = { port = 8443 }
  }
  alb_certificate_arn = var.alb_certificate_arn
  probe_port          = 9091

  environment = {
    PATHWAYS_STORAGE = "postgres"
  }
  secrets = {
    PATHWAYS_KEY_2026_11 = var.master_key_secret_arn
  }
}
