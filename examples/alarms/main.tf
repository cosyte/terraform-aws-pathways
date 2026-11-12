# The minimal deployment with the module's alarms on: one engine on ECS Fargate, its PostgreSQL
# database and one MLLP channel, plus a metrics collector beside the engine in its task and four
# CloudWatch alarms on the metrics the engine serves, each publishing to an SNS topic you already
# have.
#
# The collector reads /metrics on the engine's health endpoint, at 127.0.0.1 inside the task, with a
# token the module generates in Secrets Manager and gives to both containers. project/pathways.yaml
# turns the health endpoint on at the port alarms_health_port names.
#
# Every value here is a placeholder: the VPC and subnet ids, the account id 123456789012, the image
# digests, the secret ARN and the topic ARN. Put your own in before you plan.

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project = "pathways-alarms"
    }
  }
}

module "pathways" {
  source = "../.."

  name   = "alarms"
  vpc_id = var.vpc_id

  private_subnet_ids  = var.private_subnet_ids
  allowed_cidr_blocks = var.allowed_cidr_blocks

  # Your project's own image, by digest: project/ copied onto the Pathways image.
  image = var.image

  # One vCPU and 2 GiB, the module's default size: the collector shares the task with the engine.
  cpu    = 1024
  memory = 2048

  # The channel's MLLP source, in project/channels/adt-to-lab/channel.yaml.
  mllp_sources = {
    adt = { port = 2575 }
  }
  probe_port = 9091

  # HTTPS anywhere is the default rule (the image registry, Secrets Manager and CloudWatch, which
  # the collector writes the metrics to); the lab rule lets the channel's MLLP destination reach
  # the lab, and nowhere else on that port.
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

  # The alarms: the health endpoint on 9090 (project/pathways.yaml), the collector's image by
  # digest, and the topic they publish to. The thresholds are the module's defaults, written out.
  alarms_enabled                    = true
  alarms_sns_topic_arn              = var.alarms_sns_topic_arn
  alarms_collector_image            = var.collector_image
  alarms_health_port                = 9090
  alarms_store_down_minutes         = 2
  alarms_oldest_pending_age_seconds = 600
  alarms_refused_messages_threshold = 0
  alarms_settled_failed_threshold   = 0

  # One availability zone and no deletion protection, so that trying it out costs less and a
  # destroy succeeds. The module's defaults are Multi-AZ and protected.
  database_multi_az       = false
  database_instance_class = "db.t4g.micro"
  deletion_protection     = false
}
