# The smallest deployment: one engine on ECS Fargate and its PostgreSQL database, in an existing
# VPC, with one channel in project/ that takes ADT over MLLP from a hospital system and sends it on
# over MLLP to a lab. No HTTP source, no bucket and no SFTP.
#
# It is sized to try the module out, not to run in production: the database is in one availability
# zone, and deletion protection is off so that a destroy takes it down. Turn both back on (they are
# the module's defaults) before it carries real traffic.
#
# Every value here is a placeholder: the VPC and subnet ids, the account id 123456789012, the image
# digest and the secret ARN. Put your own in before you plan.

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project = "pathways-minimal"
    }
  }
}

module "pathways" {
  source = "../.."

  name   = "minimal"
  vpc_id = var.vpc_id

  private_subnet_ids  = var.private_subnet_ids
  allowed_cidr_blocks = var.allowed_cidr_blocks

  # Your project's own image, by digest: project/ copied onto the Pathways image.
  image = var.image

  # Half a vCPU and 1 GiB, half the module's default size: enough for one channel.
  cpu    = 512
  memory = 1024

  # The channel's MLLP source, in project/channels/adt-to-lab/channel.yaml.
  mllp_sources = {
    adt = { port = 2575 }
  }
  probe_port = 9091

  # HTTPS anywhere is the default rule (the image registry, Secrets Manager and CloudWatch Logs);
  # the lab rule lets the channel's MLLP destination reach the lab, and nowhere else on that port.
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

  # One availability zone and no deletion protection, so that trying it out costs less and a
  # destroy succeeds. The module's defaults are Multi-AZ and protected.
  database_multi_az       = false
  database_instance_class = "db.t4g.micro"
  deletion_protection     = false
}
