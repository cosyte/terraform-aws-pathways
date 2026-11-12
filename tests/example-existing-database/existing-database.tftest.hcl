# Plan-only tests of examples/existing-database, planned whole, as a caller would apply it: the engine on a database the caller already runs.
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

run "existing_database_is_used_not_created" {
  command = plan

  module {
    source = "./examples/existing-database"
  }

  assert {
    condition = (
      module.pathways.database_address == null
      && module.pathways.database_instance_arn == null
      && module.pathways.database_url_secret_arn == var.database_url_secret_arn
    )
    error_message = "The module creates no database, and the engine reads the caller's URL secret."
  }

  assert {
    condition     = output.engine_security_group_id == "sg-00000000000000000"
    error_message = "The engine's security group is an output, for the database team."
  }

  assert {
    condition     = output.nlb_dns_name == "test.example.com"
    error_message = "One MLLP source: a network load balancer."
  }

  assert {
    condition     = jsondecode(output.migrate_network_configuration).awsvpcConfiguration.assignPublicIp == "DISABLED"
    error_message = "The tasks get no public address."
  }
}
