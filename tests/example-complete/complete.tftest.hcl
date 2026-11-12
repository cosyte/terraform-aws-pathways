# Plan-only tests of examples/complete, planned whole, as a caller would apply it: the engine, the database, the bucket, SFTP and one channel.
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

run "complete_has_every_piece" {
  command = plan

  module {
    source = "./examples/complete"
  }

  assert {
    condition     = module.pathways.nlb_dns_name == "test.example.com" && module.pathways.alb_dns_name == null
    error_message = "One MLLP source: a network load balancer, and no application load balancer."
  }

  assert {
    condition = (
      module.pathways.bucket_name == "pathways-test-00000000000000000000000001"
      && module.pathways.sftp_server_id == "s-00000000000000000"
    )
    error_message = "The bucket and the SFTP server are both on."
  }

  assert {
    condition     = module.pathways.database_address == "pathways-test.example.com"
    error_message = "The module creates the database."
  }

  assert {
    condition     = jsondecode(output.migrate_network_configuration).awsvpcConfiguration.assignPublicIp == "DISABLED"
    error_message = "The tasks get no public address."
  }
}
