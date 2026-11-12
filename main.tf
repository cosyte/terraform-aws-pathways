# Pathways on ECS Fargate: the composition of the submodules under modules/, each one concern and
# each usable on its own. The module has no provider block: the caller's aws provider, its region
# and its default_tags apply, inherited by each submodule.
#
#   modules/kms              the customer managed key that encrypts the database, its secret and the logs
#   modules/logs             the engine's and the migrate task's log groups
#   modules/security_groups  who may reach the load balancers, the engine and the database
#   modules/database         PostgreSQL on RDS, encrypted, TLS forced, and the secret holding its URL
#   modules/iam              the task execution role and the task role
#   modules/load_balancers   the network load balancer for MLLP and the application load balancer for HTTP
#   modules/ecs              the cluster, the engine and migrate task definitions, and the service
#   modules/bucket           optional (bucket_enabled): an S3 bucket the engine reaches through its task role
#   modules/sftp             optional (sftp_enabled): a Transfer Family SFTP server in front of that bucket

locals {
  database_subnet_ids      = var.database_subnet_ids != null ? var.database_subnet_ids : var.private_subnet_ids
  load_balancer_subnet_ids = var.load_balancer_subnet_ids != null ? var.load_balancer_subnet_ids : var.private_subnet_ids

  # Every port the engine container listens on: each source's, and the probe listener's.
  source_ports    = concat([for s in values(var.mllp_sources) : s.port], [for s in values(var.http_sources) : s.port])
  container_ports = concat(local.source_ports, [var.probe_port])

  # The log groups live under one prefix, which the key policy lets CloudWatch Logs use.
  log_group_prefix = "/pathways/${var.name}"

  # PATHWAYS_DATABASE_URL comes from the secret the database module writes; the caller's secrets
  # join it.
  task_secrets = merge(var.secrets, {
    PATHWAYS_DATABASE_URL = module.database.url_secret_arn
  })

  # With the bucket, PATHWAYS_BUCKET names it, so a channel's s3 block reads
  # bucket: { env: PATHWAYS_BUCKET }. The task role reaches it, so no credential is passed.
  task_environment = merge(var.environment, var.bucket_enabled ? {
    PATHWAYS_BUCKET = module.bucket[0].bucket_name
  } : {})

  sftp_subnet_ids = var.sftp_subnet_ids != null ? var.sftp_subnet_ids : var.private_subnet_ids

  # Each source's target group, for the service. The load_balancers module's outputs are read only
  # after its listeners exist, which ECS needs before it attaches the service.
  service_load_balancers = merge(
    {
      for k, s in var.mllp_sources : "mllp-${k}" => {
        target_group_arn = module.load_balancers.mllp_target_group_arns[k]
        container_port   = s.port
      }
    },
    {
      for k, s in var.http_sources : "http-${k}" => {
        target_group_arn = module.load_balancers.http_target_group_arns[k]
        container_port   = s.port
      }
    },
  )

  tags = merge(var.tags, {
    "pathways:deployment" = var.name
  })
}

module "kms" {
  source = "./modules/kms"

  name                 = var.name
  log_group_prefix     = local.log_group_prefix
  deletion_window_days = var.kms_key_deletion_window_days
  tags                 = local.tags
}

module "logs" {
  source = "./modules/logs"

  log_group_prefix = local.log_group_prefix
  kms_key_arn      = module.kms.key_arn
  retention_days   = var.log_retention_days
  tags             = local.tags
}

module "security_groups" {
  source = "./modules/security_groups"

  name                = var.name
  vpc_id              = var.vpc_id
  allowed_cidr_blocks = var.allowed_cidr_blocks
  mllp_sources        = var.mllp_sources
  http_sources        = var.http_sources
  probe_port          = var.probe_port
  egress_rules        = var.egress_rules
  tags                = local.tags
}

module "database" {
  source = "./modules/database"

  name                   = var.name
  subnet_ids             = local.database_subnet_ids
  security_group_ids     = [module.security_groups.database_security_group_id]
  kms_key_arn            = module.kms.key_arn
  storage_kms_key_arn    = var.database_kms_key_arn
  engine_version         = var.database_engine_version
  parameter_group_family = var.database_parameter_group_family
  instance_class         = var.database_instance_class
  allocated_storage      = var.database_allocated_storage
  max_allocated_storage  = var.database_max_allocated_storage
  multi_az               = var.database_multi_az
  backup_retention_days  = var.database_backup_retention_days
  database_name          = var.database_name
  username               = var.database_username
  password_version       = var.database_password_version
  deletion_protection    = var.deletion_protection
  tags                   = local.tags
}

module "iam" {
  source = "./modules/iam"

  name                              = var.name
  images                            = [var.image, var.migrate_image]
  secrets                           = local.task_secrets
  repository_credentials_secret_arn = var.repository_credentials_secret_arn
  kms_key_arns                      = concat([module.kms.key_arn], var.secrets_kms_key_arns)
  log_group_arns                    = [module.logs.engine_log_group_arn, module.logs.migrate_log_group_arn]
  tags                              = local.tags
}

module "load_balancers" {
  source = "./modules/load_balancers"

  name                  = var.name
  vpc_id                = var.vpc_id
  subnet_ids            = local.load_balancer_subnet_ids
  internal              = var.load_balancer_internal
  mllp_sources          = var.mllp_sources
  http_sources          = var.http_sources
  nlb_security_group_id = module.security_groups.nlb_security_group_id
  alb_security_group_id = module.security_groups.alb_security_group_id
  http_target_protocol  = var.http_target_protocol
  alb_certificate_arn   = var.alb_certificate_arn
  alb_ssl_policy        = var.alb_ssl_policy
  probe_port            = var.probe_port
  drain_timeout_seconds = var.drain_timeout_seconds
  deletion_protection   = var.deletion_protection
  tags                  = local.tags
}

module "ecs" {
  source = "./modules/ecs"

  name                              = var.name
  image                             = var.image
  migrate_image                     = var.migrate_image
  repository_credentials_secret_arn = var.repository_credentials_secret_arn
  cpu                               = var.cpu
  memory                            = var.memory
  cpu_architecture                  = var.cpu_architecture
  container_ports                   = local.container_ports
  environment                       = local.task_environment
  secrets                           = local.task_secrets
  execution_role_arn                = module.iam.execution_role_arn
  task_role_arn                     = module.iam.task_role_arn
  engine_log_group_name             = module.logs.engine_log_group_name
  migrate_log_group_name            = module.logs.migrate_log_group_name
  drain_timeout_seconds             = var.drain_timeout_seconds
  health_check_grace_period_seconds = var.health_check_grace_period_seconds
  container_insights                = var.container_insights
  subnet_ids                        = var.private_subnet_ids
  security_group_ids                = [module.security_groups.engine_security_group_id]
  load_balancers                    = local.service_load_balancers
  tags                              = local.tags
}

module "bucket" {
  source = "./modules/bucket"
  count  = var.bucket_enabled ? 1 : 0

  name                      = var.name
  kms_key_arn               = module.kms.key_arn
  lifecycle_rules           = var.bucket_lifecycle_rules
  access_log_retention_days = var.bucket_access_log_retention_days
  task_role_name            = module.iam.task_role_name
  tags                      = local.tags
}

module "sftp" {
  source = "./modules/sftp"
  count  = var.sftp_enabled ? 1 : 0

  name                 = var.name
  vpc_id               = var.vpc_id
  subnet_ids           = local.sftp_subnet_ids
  allowed_cidr_blocks  = var.sftp_allowed_cidr_blocks
  bucket_name          = module.bucket[0].bucket_name
  kms_key_arn          = module.kms.key_arn
  users                = var.sftp_users
  security_policy_name = var.sftp_security_policy_name
  log_group_name       = "${local.log_group_prefix}/sftp"
  log_retention_days   = var.log_retention_days
  tags                 = local.tags
}
