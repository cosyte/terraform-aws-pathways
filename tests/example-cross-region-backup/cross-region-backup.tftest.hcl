# Plan-only tests of examples/cross-region-backup, planned whole, as a caller would apply it: the database's automated backups replicated to a second region.
# Every run block is `command = plan` against mocked providers: no credentials, no API call, no
# state, nothing created. The example's own provider blocks are replaced by the mocks below.
#
# Every value is synthetic: the documentation account id 123456789012, ids of zeros and counting
# digits, and names on example.com. The example's own placeholders are its defaults.

mock_provider "aws" {
  override_during = plan

  # A mocked policy document still has to be valid JSON: the roles and the key read it.
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

  mock_resource "aws_kms_key" {
    defaults = {
      arn    = "arn:aws:kms:us-east-1:123456789012:key/00000000-0000-0000-0000-000000000000"
      key_id = "00000000-0000-0000-0000-000000000000"
    }
  }

  mock_resource "aws_secretsmanager_secret" {
    defaults = {
      id  = "arn:aws:secretsmanager:us-east-1:123456789012:secret:pathways/test/database-url-AbCdEf"
      arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:pathways/test/database-url-AbCdEf"
    }
  }

  mock_resource "aws_cloudwatch_log_group" {
    defaults = {
      arn = "arn:aws:logs:us-east-1:123456789012:log-group:/pathways/test/engine"
    }
  }

  mock_resource "aws_iam_role" {
    defaults = {
      arn = "arn:aws:iam::123456789012:role/pathways-test"
    }
  }

  mock_resource "aws_db_instance" {
    defaults = {
      address = "pathways-test.example.com"
      arn     = "arn:aws:rds:us-east-1:123456789012:db:pathways-test"
    }
  }

  mock_resource "aws_ecs_cluster" {
    defaults = {
      id  = "arn:aws:ecs:us-east-1:123456789012:cluster/pathways-test"
      arn = "arn:aws:ecs:us-east-1:123456789012:cluster/pathways-test"
    }
  }

  mock_resource "aws_ecs_task_definition" {
    defaults = {
      arn = "arn:aws:ecs:us-east-1:123456789012:task-definition/pathways-test:1"
    }
  }

  mock_resource "aws_lb" {
    defaults = {
      arn      = "arn:aws:elasticloadbalancing:us-east-1:123456789012:loadbalancer/net/test/0123456789abcdef"
      dns_name = "test.example.com"
      zone_id  = "Z0000000000000000000"
    }
  }

  mock_resource "aws_lb_target_group" {
    defaults = {
      arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/test/0123456789abcdef"
    }
  }

  mock_resource "aws_security_group" {
    defaults = {
      id = "sg-00000000000000000"
    }
  }

  mock_resource "aws_s3_bucket" {
    defaults = {
      id     = "pathways-test-00000000000000000000000001"
      bucket = "pathways-test-00000000000000000000000001"
      arn    = "arn:aws:s3:::pathways-test-00000000000000000000000001"
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

mock_provider "aws" {
  alias           = "backup"
  override_during = plan

  mock_resource "aws_kms_key" {
    defaults = {
      arn    = "arn:aws:kms:us-west-2:123456789012:key/00000000-0000-0000-0000-000000000002"
      key_id = "00000000-0000-0000-0000-000000000002"
    }
  }

  mock_resource "aws_db_instance_automated_backups_replication" {
    defaults = {
      id = "arn:aws:rds:us-west-2:123456789012:auto-backup:ab-00000000000000000000000000"
    }
  }
}

run "backups_replicate_to_the_backup_region_under_its_own_key" {
  command = plan

  module {
    source = "./examples/cross-region-backup"
  }

  assert {
    condition     = aws_db_instance_automated_backups_replication.this.source_db_instance_arn == "arn:aws:rds:us-east-1:123456789012:db:pathways-test"
    error_message = "The replication copies the module's database."
  }

  assert {
    condition = (
      aws_db_instance_automated_backups_replication.this.kms_key_id == "arn:aws:kms:us-west-2:123456789012:key/00000000-0000-0000-0000-000000000002"
      && output.backup_kms_key_arn == aws_db_instance_automated_backups_replication.this.kms_key_id
    )
    error_message = "The replicated backups are encrypted under the key in the backup region, not the primary region's."
  }

  assert {
    condition     = aws_db_instance_automated_backups_replication.this.retention_period == 14 && var.backup_retention_days == 14
    error_message = "The replicated backups are kept as long as the primary's."
  }

  assert {
    condition     = aws_kms_key.backup.enable_key_rotation && aws_kms_key.backup.deletion_window_in_days == 30
    error_message = "The backup key rotates yearly and has the longest deletion window AWS allows."
  }

  assert {
    condition     = output.replicated_backups_arn == "arn:aws:rds:us-west-2:123456789012:auto-backup:ab-00000000000000000000000000"
    error_message = "The replicated backups' ARN is an output, for the restore."
  }

  assert {
    condition     = jsondecode(output.migrate_network_configuration).awsvpcConfiguration.assignPublicIp == "DISABLED"
    error_message = "The tasks get no public address."
  }
}
