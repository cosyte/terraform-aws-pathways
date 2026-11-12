# Pathways on ECS Fargate end to end, in an existing VPC: the engine and its PostgreSQL database,
# an S3 bucket the engine reaches through its task role, an SFTP server in front of that bucket for
# one partner, and the one channel in project/ that joins them. A hospital system sends ADT over
# MLLP; the channel writes each admission to the bucket under partners/lab/outbox, and the lab
# picks the files up over SFTP from its home, partners/lab.
#
# Every value here is a placeholder: the VPC and subnet ids, the account id 123456789012, the image
# digest, the secret ARN and the SSH key. Put your own in before you plan.

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

  # Your project's own image, by digest: project/ copied onto the Pathways image.
  image = var.image

  cpu    = 1024
  memory = 2048

  # The channel's MLLP source, in project/channels/adt-to-lab/channel.yaml.
  mllp_sources = {
    adt = { port = 2575 }
  }
  probe_port = 9091

  environment = {
    PATHWAYS_STORAGE = "postgres"
  }
  secrets = {
    PATHWAYS_KEY_2026_11 = var.master_key_secret_arn
  }

  # The database: PostgreSQL on RDS, Multi-AZ. The defaults are kept; see variables.tf.
  database_instance_class = "db.t4g.medium"

  # The bucket. The engine gets its name as PATHWAYS_BUCKET, and its task role may use it.
  bucket_enabled = true
  bucket_lifecycle_rules = {
    default = {
      noncurrent_version_expiration_days     = 30
      abort_incomplete_multipart_upload_days = 7
    }
    # What the lab has not picked up in 90 days goes.
    outbox = {
      prefix          = "partners/lab/outbox/"
      expiration_days = 90
    }
  }

  # SFTP for the lab, from its network only.
  sftp_enabled             = true
  sftp_allowed_cidr_blocks = var.sftp_allowed_cidr_blocks
  sftp_users = {
    lab = {
      public_keys = [var.lab_public_key]
      home_prefix = "partners/lab"
    }
  }
}
