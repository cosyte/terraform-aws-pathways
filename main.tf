# Pathways on ECS Fargate. The module has no provider block: the caller's aws provider, its region
# and its default_tags apply. The files beside this one each hold one part:
#
#   kms.tf             the customer managed key that encrypts the database, its secret and the logs
#   logs.tf            the engine's and the migrate task's log groups
#   database.tf        PostgreSQL on RDS, encrypted, TLS forced, and the secret holding its URL
#   iam.tf             the task execution role and the task role
#   security_groups.tf who may reach the load balancers, the engine and the database
#   load_balancers.tf  the network load balancer for MLLP and the application load balancer for HTTP
#   ecs.tf             the cluster, the engine and migrate task definitions, and the service

data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

data "aws_region" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  partition  = data.aws_partition.current.partition
  region     = data.aws_region.current.region

  database_subnet_ids      = var.database_subnet_ids != null ? var.database_subnet_ids : var.private_subnet_ids
  load_balancer_subnet_ids = var.load_balancer_subnet_ids != null ? var.load_balancer_subnet_ids : var.private_subnet_ids

  create_nlb = length(var.mllp_sources) > 0
  create_alb = length(var.http_sources) > 0

  # Every port the engine container listens on: each source's, and the probe listener's.
  source_ports    = concat([for s in values(var.mllp_sources) : s.port], [for s in values(var.http_sources) : s.port])
  container_ports = concat(local.source_ports, [var.probe_port])

  # The log groups live under one prefix, which the key policy lets CloudWatch Logs use.
  log_group_prefix = "/pathways/${var.name}"

  # PATHWAYS_DATABASE_URL comes from the secret the module writes; the caller's secrets join it.
  task_secrets = merge(var.secrets, {
    PATHWAYS_DATABASE_URL = aws_secretsmanager_secret.database_url.arn
  })

  tags = merge(var.tags, {
    "pathways:deployment" = var.name
  })
}
