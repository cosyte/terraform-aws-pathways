# Files only: partners exchange files over SFTP, and the engine reads and writes them in the S3
# bucket behind it. No MLLP or HTTP source, so no load balancer exists. Two partners, each locked to
# its own prefix: the lab uploads results to its inbox, and the clinic picks up its copies from its
# outbox. The one channel in project/ moves each result from the lab's inbox to the clinic's outbox.
#
# Every value here is a placeholder: the VPC and subnet ids, the account id 123456789012, the image
# digest, the secret ARN and the SSH keys. Put your own in before you plan.

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project = "pathways-files"
    }
  }
}

module "pathways" {
  source = "../.."

  name   = "files"
  vpc_id = var.vpc_id

  private_subnet_ids = var.private_subnet_ids

  # No load balancer exists without a source of its kind, so this opens nothing; the module asks for
  # it all the same. SFTP has its own list below.
  allowed_cidr_blocks = var.sftp_allowed_cidr_blocks

  image = var.image

  # No MLLP or HTTP source: the channel reads files. The probe listener is still there for ECS.
  mllp_sources = {}
  http_sources = {}
  probe_port   = 9091

  environment = {
    PATHWAYS_STORAGE = "postgres"
  }
  secrets = {
    PATHWAYS_KEY_2026_11 = var.master_key_secret_arn
  }

  # The bucket. The engine gets its name as PATHWAYS_BUCKET, and its task role may use it.
  bucket_enabled = true
  bucket_lifecycle_rules = {
    default = {
      noncurrent_version_expiration_days     = 30
      abort_incomplete_multipart_upload_days = 7
    }
    # What the clinic has not picked up in 30 days goes.
    clinic_outbox = {
      prefix          = "partners/clinic/outbox/"
      expiration_days = 30
    }
  }

  # SFTP for both partners, from their networks only, each in its own home.
  sftp_enabled             = true
  sftp_allowed_cidr_blocks = var.sftp_allowed_cidr_blocks
  sftp_users = {
    lab = {
      public_keys = [var.lab_public_key]
      home_prefix = "partners/lab"
    }
    clinic = {
      public_keys = [var.clinic_public_key]
      home_prefix = "partners/clinic"
    }
  }
}
