# MLLP only: every source is HL7 v2 over MLLP, behind one internal network load balancer, and every
# destination is MLLP too. No application load balancer, no certificate in ACM, no bucket and no
# SFTP. Two channels: ADT from the hospital system to the lab, and results from the lab back to the
# EHR. The network load balancer passes each TCP connection straight through to the engine, which
# terminates its own TLS, so the certificates live in the image, not in AWS.
#
# Every value here is a placeholder: the VPC and subnet ids, the account id 123456789012, the image
# digest and the secret ARN. Put your own in before you plan.

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project = "pathways-mllp-only"
    }
  }
}

module "pathways" {
  source = "../.."

  name   = "mllp-only"
  vpc_id = var.vpc_id

  private_subnet_ids = var.private_subnet_ids

  # Who may connect to the MLLP listeners: the hospital system and the lab, each on its own network.
  allowed_cidr_blocks = concat(var.hospital_cidr_blocks, var.lab_cidr_blocks)

  image = var.image

  # One listener per channel's source; the network load balancer exists because there is at least
  # one. No http_sources, so no application load balancer and no certificate.
  mllp_sources = {
    adt     = { port = 2575 }
    results = { port = 2577 }
  }
  probe_port = 9091

  # Each destination's MLLP port on its own network, and HTTPS for the AWS APIs.
  egress_rules = {
    https = {
      port        = 443
      cidr_blocks = ["0.0.0.0/0"]
    }
    lab = {
      port        = 2576
      cidr_blocks = var.lab_cidr_blocks
    }
    ehr = {
      port        = 2578
      cidr_blocks = var.ehr_cidr_blocks
    }
  }

  environment = {
    PATHWAYS_STORAGE = "postgres"
  }
  secrets = {
    PATHWAYS_KEY_2026_11 = var.master_key_secret_arn
  }
}
