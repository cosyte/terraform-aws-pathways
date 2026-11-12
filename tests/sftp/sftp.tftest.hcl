# Plan-only tests of modules/sftp on its own, against a mocked aws provider. The policies are
# asserted on the policy documents' arguments; the mocked documents' JSON is a fixed empty policy.
# Every value is synthetic: the documentation account id 123456789012, ids of zeros, private CIDR
# blocks, and SSH public keys that are runs of A, which no private key matches.

mock_provider "aws" {
  override_during = plan

  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }

  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
    }
  }

  mock_data "aws_partition" {
    defaults = {
      partition = "aws"
    }
  }

  mock_data "aws_region" {
    defaults = {
      region = "us-east-1"
    }
  }

  mock_resource "aws_security_group" {
    defaults = {
      id = "sg-00000000000000000"
    }
  }

  mock_resource "aws_cloudwatch_log_group" {
    defaults = {
      arn = "arn:aws:logs:us-east-1:123456789012:log-group:/pathways/test/sftp"
    }
  }

  mock_resource "aws_iam_role" {
    defaults = {
      arn = "arn:aws:iam::123456789012:role/pathways-test-sftp"
    }
  }

  mock_resource "aws_transfer_server" {
    defaults = {
      id       = "s-00000000000000000"
      arn      = "arn:aws:transfer:us-east-1:123456789012:server/s-00000000000000000"
      endpoint = "s-00000000000000000.server.transfer.us-east-1.amazonaws.com"
    }
  }
}

variables {
  name                = "test"
  vpc_id              = "vpc-00000000000000000"
  subnet_ids          = ["subnet-00000000000000001", "subnet-00000000000000002"]
  allowed_cidr_blocks = ["10.30.0.0/24"]
  bucket_name         = "pathways-test-00000000000000000000000001"
  kms_key_arn         = "arn:aws:kms:us-east-1:123456789012:key/00000000-0000-0000-0000-000000000000"
  log_group_name      = "/pathways/test/sftp"
  users = {
    lab = {
      public_keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA lab-key",
        "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAAAAAAAAAAAAAAAA",
      ]
      home_prefix = "partners/lab"
    }
  }
}

# ---------------------------------------------------------------------------
# The server
# ---------------------------------------------------------------------------

run "server_is_sftp_on_an_internal_vpc_endpoint" {
  command = plan

  module {
    source = "./modules/sftp"
  }

  assert {
    condition = (
      aws_transfer_server.this.endpoint_type == "VPC"
      && toset(aws_transfer_server.this.protocols) == toset(["SFTP"])
      && aws_transfer_server.this.identity_provider_type == "SERVICE_MANAGED"
      && aws_transfer_server.this.domain == "S3"
    )
    error_message = "The server speaks SFTP alone, on a VPC endpoint, with service managed users, onto S3."
  }

  assert {
    condition = (
      one(aws_transfer_server.this.endpoint_details).vpc_id == var.vpc_id
      && toset(one(aws_transfer_server.this.endpoint_details).subnet_ids) == toset(var.subnet_ids)
      && toset(one(aws_transfer_server.this.endpoint_details).security_group_ids) == toset([aws_security_group.this.id])
    )
    error_message = "The endpoint is in the given VPC and subnets, behind the module's security group."
  }

  assert {
    condition     = length(coalesce(one(aws_transfer_server.this.endpoint_details).address_allocation_ids, [])) == 0
    error_message = "The endpoint gets no Elastic IP, so it is internal to the VPC."
  }

  assert {
    condition     = aws_transfer_server.this.security_policy_name == "TransferSecurityPolicy-2024-01"
    error_message = "The server uses the 2024-01 security policy by default."
  }
}

run "endpoint_admits_the_allowed_networks_on_port_22_only" {
  command = plan

  module {
    source = "./modules/sftp"
  }

  variables {
    allowed_cidr_blocks = ["10.30.0.0/24", "192.168.10.0/24"]
  }

  assert {
    condition = toset([for r in values(aws_vpc_security_group_ingress_rule.this) : "${r.cidr_ipv4}:${r.ip_protocol}:${r.from_port}-${r.to_port}"]) == toset([
      "10.30.0.0/24:tcp:22-22", "192.168.10.0/24:tcp:22-22",
    ])
    error_message = "The endpoint admits each allowed block on TCP 22, and nothing else."
  }
}

run "server_logs_to_an_encrypted_group" {
  command = plan

  module {
    source = "./modules/sftp"
  }

  assert {
    condition = (
      aws_cloudwatch_log_group.this.name == "/pathways/test/sftp"
      && aws_cloudwatch_log_group.this.kms_key_id == var.kms_key_arn
      && aws_cloudwatch_log_group.this.retention_in_days == 365
    )
    error_message = "The log group is encrypted under the key given and keeps logs for log_retention_days, 365 by default."
  }

  assert {
    condition = (
      toset(aws_transfer_server.this.structured_log_destinations) == toset(["${aws_cloudwatch_log_group.this.arn}:*"])
      && aws_transfer_server.this.logging_role == aws_iam_role.logging.arn
    )
    error_message = "The server writes structured logs to the module's log group, with its logging role."
  }

  assert {
    condition = anytrue([
      for s in data.aws_iam_policy_document.logging.statement :
      toset(s.resources) == toset(["${aws_cloudwatch_log_group.this.arn}:*"])
    ]) && alltrue([for s in data.aws_iam_policy_document.logging.statement : alltrue([for r in s.resources : startswith(r, aws_cloudwatch_log_group.this.arn)])])
    error_message = "The logging role writes to the module's log group alone."
  }
}

# ---------------------------------------------------------------------------
# The users
# ---------------------------------------------------------------------------

run "each_user_is_locked_to_its_home_prefix" {
  command = plan

  module {
    source = "./modules/sftp"
  }

  assert {
    condition = (
      aws_transfer_user.this["lab"].home_directory_type == "LOGICAL"
      && [for m in aws_transfer_user.this["lab"].home_directory_mappings : [m.entry, m.target]] == [["/", "/pathways-test-00000000000000000000000001/partners/lab"]]
      && aws_transfer_user.this["lab"].role == aws_iam_role.user["lab"].arn
    )
    error_message = "The user sees its home prefix as / and nothing above it."
  }

  assert {
    condition = anytrue([
      for s in data.aws_iam_policy_document.user["lab"].statement :
      toset(s.actions) == toset(["s3:ListBucket"])
      && anytrue([for c in s.condition : c.variable == "s3:prefix" && toset(c.values) == toset(["partners/lab", "partners/lab/*"])])
    ])
    error_message = "The user's role lists the bucket under the home prefix alone."
  }

  assert {
    condition = anytrue([
      for s in data.aws_iam_policy_document.user["lab"].statement :
      toset(s.actions) == toset(["s3:GetObject", "s3:PutObject", "s3:DeleteObject"])
      && toset(s.resources) == toset(["arn:aws:s3:::pathways-test-00000000000000000000000001/partners/lab/*"])
    ])
    error_message = "The user's role reads, writes and deletes objects under the home prefix alone."
  }

  assert {
    condition = anytrue([
      for s in data.aws_iam_policy_document.user["lab"].statement :
      toset(s.actions) == toset(["kms:GenerateDataKey", "kms:Decrypt"]) && toset(s.resources) == toset([var.kms_key_arn])
      && anytrue([for c in s.condition : c.variable == "kms:ViaService" && toset(c.values) == toset(["s3.us-east-1.amazonaws.com"])])
    ])
    error_message = "The user's role uses the key through S3 alone."
  }

  assert {
    condition = anytrue([
      for s in data.aws_iam_policy_document.user_assume.statement :
      contains(flatten([for p in s.principals : tolist(p.identifiers)]), "transfer.amazonaws.com")
      && anytrue([for c in s.condition : c.variable == "aws:SourceArn" && toset(c.values) == toset([aws_transfer_server.this.arn])])
      && anytrue([for c in s.condition : c.variable == "aws:SourceAccount" && toset(c.values) == toset(["123456789012"])])
    ])
    error_message = "Only this Transfer Family server, in this account, may assume the users' roles."
  }
}

run "each_public_key_is_registered_for_its_user" {
  command = plan

  module {
    source = "./modules/sftp"
  }

  assert {
    condition = (
      length(aws_transfer_ssh_key.this) == 2
      && alltrue([for k in values(aws_transfer_ssh_key.this) : k.user_name == "lab" && contains(var.users.lab.public_keys, k.body)])
    )
    error_message = "Each key of each user is registered for that user."
  }
}

run "no_users_no_roles" {
  command = plan

  module {
    source = "./modules/sftp"
  }

  variables {
    users = {}
  }

  assert {
    condition     = length(aws_transfer_user.this) == 0 && length(aws_iam_role.user) == 0 && length(aws_transfer_ssh_key.this) == 0
    error_message = "With no user there is no user, role or key."
  }
}

# ---------------------------------------------------------------------------
# Inputs refused
# ---------------------------------------------------------------------------

run "anywhere_is_refused" {
  command = plan

  module {
    source = "./modules/sftp"
  }

  variables {
    allowed_cidr_blocks = ["10.30.0.0/24", "0.0.0.0/0"]
  }

  expect_failures = [var.allowed_cidr_blocks]
}

run "no_allowed_cidr_block_is_refused" {
  command = plan

  module {
    source = "./modules/sftp"
  }

  variables {
    allowed_cidr_blocks = []
  }

  expect_failures = [var.allowed_cidr_blocks]
}

run "a_cidr_block_that_is_not_one_is_refused" {
  command = plan

  module {
    source = "./modules/sftp"
  }

  variables {
    allowed_cidr_blocks = ["partners.example.com"]
  }

  expect_failures = [var.allowed_cidr_blocks]
}

run "no_subnet_is_refused" {
  command = plan

  module {
    source = "./modules/sftp"
  }

  variables {
    subnet_ids = []
  }

  expect_failures = [var.subnet_ids]
}

run "user_without_a_key_is_refused" {
  command = plan

  module {
    source = "./modules/sftp"
  }

  variables {
    users = {
      lab = { public_keys = [], home_prefix = "partners/lab" }
    }
  }

  expect_failures = [var.users]
}

run "private_key_is_refused" {
  command = plan

  module {
    source = "./modules/sftp"
  }

  variables {
    users = {
      lab = { public_keys = ["-----BEGIN OPENSSH PRIVATE KEY-----"], home_prefix = "partners/lab" }
    }
  }

  expect_failures = [var.users]
}

run "home_prefix_climbing_out_is_refused" {
  command = plan

  module {
    source = "./modules/sftp"
  }

  variables {
    users = {
      lab = {
        public_keys = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"]
        home_prefix = "partners/../lab"
      }
    }
  }

  expect_failures = [var.users]
}

run "home_prefix_with_a_leading_slash_is_refused" {
  command = plan

  module {
    source = "./modules/sftp"
  }

  variables {
    users = {
      lab = {
        public_keys = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"]
        home_prefix = "/partners/lab"
      }
    }
  }

  expect_failures = [var.users]
}

run "empty_home_prefix_is_refused" {
  command = plan

  module {
    source = "./modules/sftp"
  }

  variables {
    users = {
      lab = {
        public_keys = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"]
        home_prefix = ""
      }
    }
  }

  expect_failures = [var.users]
}

run "user_name_transfer_family_refuses_is_refused" {
  command = plan

  module {
    source = "./modules/sftp"
  }

  variables {
    users = {
      "-lab" = {
        public_keys = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"]
        home_prefix = "partners/lab"
      }
    }
  }

  expect_failures = [var.users]
}

run "key_alias_is_refused" {
  command = plan

  module {
    source = "./modules/sftp"
  }

  variables {
    kms_key_arn = "alias/pathways-test"
  }

  expect_failures = [var.kms_key_arn]
}

run "bucket_name_s3_refuses_is_refused" {
  command = plan

  module {
    source = "./modules/sftp"
  }

  variables {
    bucket_name = "Pathways_Test"
  }

  expect_failures = [var.bucket_name]
}

run "security_policy_that_is_not_one_is_refused" {
  command = plan

  module {
    source = "./modules/sftp"
  }

  variables {
    security_policy_name = "none"
  }

  expect_failures = [var.security_policy_name]
}
