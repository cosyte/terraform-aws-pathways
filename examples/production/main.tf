# Production with one engine: the module's defaults, kept, with the database's warm standby. The
# engine runs as a service of one task; ECS replaces it if it stops or stalls. The database is
# Multi-AZ: RDS keeps a synchronous standby in a second availability zone and fails over to it on
# its own. Deletion protection is on, backups are kept 35 days, and the database's storage, backups
# and final snapshot are under a key of your own, so a destroy of this module cannot make them
# unreadable.
#
# A standby engine (pathways start --standby) is not here: on ECS it needs support in this module
# that is not written yet. See the README.
#
# Every value here is a placeholder: the VPC and subnet ids, the account id 123456789012, the image
# digest, the secret and key ARNs. Put your own in before you plan.

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project = "pathways-production"
    }
  }
}

module "pathways" {
  source = "../.."

  name   = "production"
  vpc_id = var.vpc_id

  private_subnet_ids  = var.private_subnet_ids
  allowed_cidr_blocks = var.allowed_cidr_blocks

  # Your project's own image, by digest: project/ copied onto the Pathways image.
  image = var.image

  # Two vCPU and 4 GiB: room for several busy channels. Measure your own load and size to it.
  cpu    = 2048
  memory = 4096

  # The channel's MLLP source, in project/channels/adt-to-lab/channel.yaml.
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

  # The database: Multi-AZ and protected from deletion, which are the module's defaults, written out
  # here so a reader sees them. A general purpose instance, room to grow, and the longest automated
  # backup window RDS allows.
  database_multi_az              = true
  deletion_protection            = true
  database_instance_class        = "db.m7g.large"
  database_allocated_storage     = 100
  database_max_allocated_storage = 500
  database_backup_retention_days = 35

  # A key of your own, which this module does not manage, so the final snapshot outlives a destroy.
  database_kms_key_arn = var.database_kms_key_arn
}
