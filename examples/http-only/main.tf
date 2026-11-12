# HTTP only: every source is HTTPS, behind one internal application load balancer, and no network
# load balancer exists. One channel takes orders as JSON over HTTPS from an ordering system and
# sends each on over HTTPS to the lab's API. The load balancer terminates TLS with your ACM
# certificate under a TLS 1.3 policy, and connects to the engine over HTTPS again, so the message is
# encrypted on both hops.
#
# Every value here is a placeholder: the VPC and subnet ids, the account id 123456789012, the image
# digest, the certificate and the secret ARNs. Put your own in before you plan.

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project = "pathways-http-only"
    }
  }
}

module "pathways" {
  source = "../.."

  name   = "http-only"
  vpc_id = var.vpc_id

  private_subnet_ids  = var.private_subnet_ids
  allowed_cidr_blocks = var.allowed_cidr_blocks

  image = var.image

  # One HTTPS listener on the application load balancer, on the source's own port. No mllp_sources,
  # so no network load balancer.
  http_sources = {
    orders = { port = 8443 }
  }
  alb_certificate_arn = var.alb_certificate_arn

  # The engine's HTTP source has its own tls block, so the load balancer reaches it over HTTPS (the
  # module's default), written out here.
  http_target_protocol = "HTTPS"
  probe_port           = 9091

  # HTTPS anywhere is the default rule, and the lab's API is HTTPS too: one rule covers the AWS APIs
  # and the destination. Narrow it to the lab's network and VPC endpoints when you have them.
  egress_rules = {
    https = {
      port        = 443
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  environment = {
    PATHWAYS_STORAGE = "postgres"
  }
  secrets = {
    PATHWAYS_KEY_2026_11 = var.master_key_secret_arn
    # The bearer token the ordering system sends, which the channel's source checks.
    ORDERS_TOKEN = var.orders_token_secret_arn
  }
}
