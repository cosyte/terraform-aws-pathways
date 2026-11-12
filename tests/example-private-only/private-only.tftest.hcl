# Plan-only tests of examples/private-only, planned whole, as a caller would apply it: no public ingress and no NAT gateway, with VPC endpoints for the AWS APIs.
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
      id         = "vpc-0a1b2c3d4e5f60718"
      cidr_block = "10.0.0.0/16"
    }
  }

  mock_resource "aws_vpc_endpoint" {
    defaults = {
      id             = "vpce-00000000000000000"
      prefix_list_id = "pl-00000000"
    }
  }
}

run "private_only_reaches_aws_through_endpoints" {
  command = plan

  module {
    source = "./examples/private-only"
  }

  assert {
    condition     = toset(keys(aws_vpc_endpoint.interface)) == toset(["ecr.api", "ecr.dkr", "secretsmanager", "logs"])
    error_message = "Interface endpoints for the image registry, Secrets Manager and CloudWatch Logs."
  }

  assert {
    condition = alltrue([
      for k, e in aws_vpc_endpoint.interface :
      e.private_dns_enabled && e.vpc_endpoint_type == "Interface" && e.service_name == "com.amazonaws.us-east-1.${k}"
      && e.security_group_ids == toset([aws_security_group.endpoints.id])
    ])
    error_message = "Each interface endpoint answers on the service's own name, behind the endpoints' security group."
  }

  assert {
    condition = (
      aws_vpc_security_group_ingress_rule.endpoints_from_engine.referenced_security_group_id == module.pathways.engine_security_group_id
      && aws_vpc_security_group_ingress_rule.endpoints_from_engine.from_port == 443
      && aws_vpc_security_group_ingress_rule.endpoints_from_engine.to_port == 443
    )
    error_message = "The endpoints admit the engine alone, on 443."
  }

  assert {
    condition = (
      aws_vpc_endpoint.s3.vpc_endpoint_type == "Gateway"
      && aws_vpc_endpoint.s3.route_table_ids == toset(var.private_route_table_ids)
      && aws_vpc_security_group_egress_rule.engine_to_s3.prefix_list_id == "pl-00000000"
      && aws_vpc_security_group_egress_rule.engine_to_s3.security_group_id == module.pathways.engine_security_group_id
      && aws_vpc_security_group_egress_rule.engine_to_s3.cidr_ipv4 == null
    )
    error_message = "S3 is reached through its gateway endpoint, by its prefix list, not by an open CIDR block."
  }

  assert {
    condition     = output.nlb_dns_name == "test.example.com" && module.pathways.alb_dns_name == null
    error_message = "One MLLP source: an internal network load balancer."
  }

  assert {
    condition     = jsondecode(output.migrate_network_configuration).awsvpcConfiguration.assignPublicIp == "DISABLED"
    error_message = "The tasks get no public address."
  }
}
