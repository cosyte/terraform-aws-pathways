# Plan-only tests of modules/load_balancers on its own, against a mocked aws provider. Every value is
# synthetic: the documentation account id 123456789012, ids of zeros and names on example.com.

mock_provider "aws" {
  override_during = plan

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
}

variables {
  name                  = "test"
  vpc_id                = "vpc-00000000000000000"
  subnet_ids            = ["subnet-00000000000000001", "subnet-00000000000000002"]
  nlb_security_group_id = "sg-00000000000000001"
  mllp_sources = {
    adt = { port = 2575 }
  }
}

run "nlb_passes_mllp_through_and_checks_readiness" {
  command = plan

  module {
    source = "./modules/load_balancers"
  }

  assert {
    condition     = aws_lb.nlb[0].load_balancer_type == "network" && aws_lb.nlb[0].internal && aws_lb.nlb[0].enable_deletion_protection
    error_message = "MLLP sources get an internal network load balancer, protected from deletion."
  }

  assert {
    condition     = aws_lb.nlb[0].security_groups == toset(["sg-00000000000000001"])
    error_message = "The network load balancer sits in the security group given."
  }

  assert {
    condition     = aws_lb_listener.mllp["adt"].protocol == "TCP" && aws_lb_listener.mllp["adt"].port == 2575
    error_message = "Each MLLP source gets a TCP listener on its port: the engine terminates its own TLS."
  }

  assert {
    condition     = aws_lb_target_group.mllp["adt"].protocol == "TCP" && aws_lb_target_group.mllp["adt"].target_type == "ip"
    error_message = "The MLLP target group passes TCP to the tasks' addresses."
  }

  assert {
    condition = (
      aws_lb_target_group.mllp["adt"].health_check[0].protocol == "HTTP"
      && aws_lb_target_group.mllp["adt"].health_check[0].path == "/readyz"
      && aws_lb_target_group.mllp["adt"].health_check[0].port == "9091"
      && aws_lb_target_group.mllp["adt"].health_check[0].matcher == "200"
    )
    error_message = "Target health is GET /readyz on the probe port."
  }

  assert {
    condition     = length(aws_lb.alb) == 0 && length(aws_lb_listener.http) == 0 && output.alb_dns_name == null
    error_message = "No HTTP source, no application load balancer."
  }

  assert {
    condition     = output.nlb_dns_name == "test.example.com" && keys(output.mllp_target_group_arns) == ["adt"]
    error_message = "The outputs give the network load balancer's name and each MLLP source's target group."
  }
}

run "drain_sets_the_deregistration_delay" {
  command = plan

  module {
    source = "./modules/load_balancers"
  }

  variables {
    drain_timeout_seconds = 90
  }

  assert {
    condition     = aws_lb_target_group.mllp["adt"].deregistration_delay == "90"
    error_message = "The network load balancer's deregistration delay is drain_timeout_seconds."
  }

  assert {
    condition     = aws_lb_target_group.mllp["adt"].connection_termination == true
    error_message = "At the end of the delay the network load balancer closes the connections still open."
  }
}

run "http_sources_get_an_https_alb" {
  command = plan

  module {
    source = "./modules/load_balancers"
  }

  variables {
    http_sources          = { orders = { port = 8443 } }
    alb_security_group_id = "sg-00000000000000002"
    alb_certificate_arn   = "arn:aws:acm:us-east-1:123456789012:certificate/00000000-0000-0000-0000-000000000000"
  }

  assert {
    condition     = aws_lb.alb[0].load_balancer_type == "application" && aws_lb.alb[0].internal && aws_lb.alb[0].drop_invalid_header_fields
    error_message = "HTTP sources get an internal application load balancer that drops invalid headers."
  }

  assert {
    condition = (
      aws_lb_listener.http["orders"].protocol == "HTTPS"
      && aws_lb_listener.http["orders"].ssl_policy == "ELBSecurityPolicy-TLS13-1-2-2021-06"
    )
    error_message = "The HTTP listeners are HTTPS with a TLS 1.3 policy."
  }

  assert {
    condition = (
      aws_lb_target_group.http["orders"].protocol == "HTTPS"
      && aws_lb_target_group.http["orders"].health_check[0].path == "/readyz"
      && aws_lb_target_group.http["orders"].deregistration_delay == "60"
    )
    error_message = "The HTTP target group reaches the engine over HTTPS, checks /readyz and drains for drain_timeout_seconds."
  }

  assert {
    condition     = keys(output.http_target_group_arns) == ["orders"]
    error_message = "The outputs give each HTTP source's target group."
  }
}

run "no_sources_no_load_balancers" {
  command = plan

  module {
    source = "./modules/load_balancers"
  }

  variables {
    mllp_sources = {}
  }

  assert {
    condition     = length(aws_lb.nlb) == 0 && length(aws_lb.alb) == 0 && output.nlb_dns_name == null && output.mllp_target_group_arns == {}
    error_message = "With no source there is no load balancer."
  }
}

run "http_sources_without_a_certificate_are_refused" {
  command = plan

  module {
    source = "./modules/load_balancers"
  }

  variables {
    http_sources          = { orders = { port = 8443 } }
    alb_security_group_id = "sg-00000000000000002"
  }

  expect_failures = [var.alb_certificate_arn]
}

run "mllp_sources_without_a_security_group_are_refused" {
  command = plan

  module {
    source = "./modules/load_balancers"
  }

  variables {
    nlb_security_group_id = null
  }

  expect_failures = [var.nlb_security_group_id]
}

run "name_too_long_for_a_target_group_is_refused" {
  command = plan

  module {
    source = "./modules/load_balancers"
  }

  variables {
    name = "a-name-much-too-long-for-aws"
  }

  expect_failures = [var.name]
}
