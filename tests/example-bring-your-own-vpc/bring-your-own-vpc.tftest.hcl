# Plan-only tests of examples/bring-your-own-vpc, planned whole, as a caller would apply it: a VPC and subnets found by their tags, each tier in its own.
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

  mock_data "aws_vpc" {
    defaults = {
      id         = "vpc-00000000000000001"
      cidr_block = "10.0.0.0/16"
    }
  }
}

run "each_tier_goes_in_its_own_subnets" {
  command = plan

  module {
    source = "./examples/bring-your-own-vpc"
  }

  # Each tier's subnets, out of order, as AWS may return them.
  override_data {
    target = data.aws_subnets.app
    values = {
      ids = ["subnet-00000000000000012", "subnet-00000000000000011"]
    }
  }

  override_data {
    target = data.aws_subnets.data
    values = {
      ids = ["subnet-00000000000000022", "subnet-00000000000000021"]
    }
  }

  override_data {
    target = data.aws_subnets.edge
    values = {
      ids = ["subnet-00000000000000032", "subnet-00000000000000031"]
    }
  }

  assert {
    condition     = output.vpc_id == "vpc-00000000000000001"
    error_message = "The module runs in the VPC the tags found."
  }

  assert {
    condition     = jsondecode(output.migrate_network_configuration).awsvpcConfiguration.subnets == ["subnet-00000000000000011", "subnet-00000000000000012"]
    error_message = "The engine and the migrate task run in the app subnets, sorted so the order AWS returns them in does not change the plan."
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
