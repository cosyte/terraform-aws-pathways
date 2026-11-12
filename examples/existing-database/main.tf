# Pathways on a PostgreSQL database you already run, instead of the RDS instance the module creates:
# an RDS or Aurora PostgreSQL instance your database team keeps, in the same VPC. The module creates
# no database, no subnet group and no URL secret. The engine reads its connection URL from your
# secret (database_url_secret_arn), and the module lets the engine reach your database's security
# group on 5432 and adds a rule to that group admitting the engine (database_security_group_id).
#
# Every value here is a placeholder: the VPC, subnet and security group ids, the account id
# 123456789012, the image digest and the secret ARNs. Put your own in before you plan.

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project = "pathways-existing-database"
    }
  }
}

module "pathways" {
  source = "../.."

  name   = "existing-db"
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

  # Your database. The secret holds one postgres:// URL with its user and password, and ECS injects
  # it as PATHWAYS_DATABASE_URL. If it is encrypted under a customer managed key, add that key to
  # secrets_kms_key_arns so the task execution role may read it.
  database_url_secret_arn    = var.database_url_secret_arn
  database_security_group_id = var.database_security_group_id
  secrets_kms_key_arns       = var.database_url_secret_kms_key_arns
}
