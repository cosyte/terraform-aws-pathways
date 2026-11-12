# One engine in the primary region, with the database's automated backups replicated to a second
# region, so the data survives the loss of the first. RDS copies each snapshot and the transaction
# logs to the backup region and keeps them there for backup_retention_days, encrypted under a key
# that lives in that region. Nothing runs in the backup region until you restore: the README walks
# through the restore, by hand, into a new instance there.
#
# Promotion is not here: a standing engine in the second region that takes over on its own waits on
# the engine. See ../second-region-disaster-recovery.
#
# Every value here is a placeholder: the VPC and subnet ids, the account id 123456789012, the image
# digest and the secret ARN. Put your own in before you plan.

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project = "pathways-backup"
    }
  }
}

# The backup region: the replicated backups and their key are created there.
provider "aws" {
  alias  = "backup"
  region = var.backup_region

  default_tags {
    tags = {
      Project = "pathways-backup"
    }
  }
}

module "pathways" {
  source = "../.."

  name   = "backup"
  vpc_id = var.vpc_id

  private_subnet_ids  = var.private_subnet_ids
  allowed_cidr_blocks = var.allowed_cidr_blocks

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

  database_backup_retention_days = var.backup_retention_days
}

# The key the replicated backups are encrypted under, in the backup region. It must outlive the
# primary region's key: a restore there never needs the first region.
resource "aws_kms_key" "backup" {
  provider = aws.backup

  description             = "Pathways backup: the database's automated backups replicated to ${var.backup_region}"
  enable_key_rotation     = true
  deletion_window_in_days = 30
}

resource "aws_kms_alias" "backup" {
  provider = aws.backup

  name          = "alias/pathways-backup-database"
  target_key_id = aws_kms_key.backup.key_id
}

resource "aws_db_instance_automated_backups_replication" "this" {
  provider = aws.backup

  source_db_instance_arn = module.pathways.database_instance_arn
  kms_key_id             = aws_kms_key.backup.arn
  retention_period       = var.backup_retention_days
}
