# Plan-only tests of modules/security_groups on its own, against a mocked aws provider. Every value
# is synthetic: ids of zeros and a private CIDR block.

mock_provider "aws" {
  override_during = plan

  mock_resource "aws_security_group" {
    defaults = {
      id = "sg-00000000000000000"
    }
  }
}

variables {
  name                = "test"
  vpc_id              = "vpc-00000000000000000"
  allowed_cidr_blocks = ["10.20.0.0/16"]
  mllp_sources = {
    adt = { port = 2575 }
  }
}

run "database_admits_the_engine_only" {
  command = plan

  module {
    source = "./modules/security_groups"
  }

  assert {
    condition = (
      aws_vpc_security_group_ingress_rule.database_from_engine.referenced_security_group_id == aws_security_group.engine.id
      && aws_vpc_security_group_ingress_rule.database_from_engine.from_port == 5432
      && aws_vpc_security_group_ingress_rule.database_from_engine.to_port == 5432
    )
    error_message = "Only the engine's security group may reach the database, on 5432."
  }

  assert {
    condition     = aws_vpc_security_group_egress_rule.engine_to_database.referenced_security_group_id == aws_security_group.database[0].id
    error_message = "The engine may reach the database."
  }
}

run "existing_database_group_is_reached_not_created" {
  command = plan

  module {
    source = "./modules/security_groups"
  }

  variables {
    database_security_group_id = "sg-00000000000000009"
  }

  assert {
    condition     = length(aws_security_group.database) == 0 && output.database_security_group_id == "sg-00000000000000009"
    error_message = "With database_security_group_id the module creates no database group and uses the one given."
  }

  assert {
    condition = (
      aws_vpc_security_group_egress_rule.engine_to_database.referenced_security_group_id == "sg-00000000000000009"
      && aws_vpc_security_group_ingress_rule.database_from_engine.security_group_id == "sg-00000000000000009"
      && aws_vpc_security_group_ingress_rule.database_from_engine.referenced_security_group_id == aws_security_group.engine.id
      && aws_vpc_security_group_ingress_rule.database_from_engine.from_port == 5432
    )
    error_message = "The engine may reach the existing database's group on 5432, and that group admits the engine on 5432."
  }
}

run "nlb_admits_allowed_cidr_blocks_on_the_mllp_ports" {
  command = plan

  module {
    source = "./modules/security_groups"
  }

  assert {
    condition     = [for r in values(aws_vpc_security_group_ingress_rule.nlb) : [r.cidr_ipv4, r.from_port]] == [["10.20.0.0/16", 2575]]
    error_message = "The network load balancer admits allowed_cidr_blocks only, on each MLLP source's port."
  }

  assert {
    condition     = toset([for r in values(aws_vpc_security_group_egress_rule.nlb_to_engine) : r.from_port]) == toset([2575, 9091])
    error_message = "The network load balancer may reach the engine on the MLLP ports and the probe port only."
  }

  assert {
    condition     = toset([for r in values(aws_vpc_security_group_ingress_rule.engine_from_nlb) : r.from_port]) == toset([2575, 9091])
    error_message = "The engine admits the network load balancer on the MLLP ports and the probe port only."
  }

  assert {
    condition     = length(aws_security_group.alb) == 0 && length(aws_vpc_security_group_ingress_rule.alb) == 0 && output.alb_security_group_id == null
    error_message = "No HTTP source, no application load balancer group."
  }
}

run "alb_group_comes_with_http_sources" {
  command = plan

  module {
    source = "./modules/security_groups"
  }

  variables {
    mllp_sources = {}
    http_sources = { orders = { port = 8443 } }
  }

  assert {
    condition     = [for r in values(aws_vpc_security_group_ingress_rule.alb) : [r.cidr_ipv4, r.from_port]] == [["10.20.0.0/16", 8443]]
    error_message = "The application load balancer admits allowed_cidr_blocks only, on each HTTP source's port."
  }

  assert {
    condition     = length(aws_security_group.nlb) == 0 && output.nlb_security_group_id == null && output.alb_security_group_id == "sg-00000000000000000"
    error_message = "HTTP sources alone: an application load balancer group and no network load balancer group."
  }
}

run "engine_egress_defaults_to_https" {
  command = plan

  module {
    source = "./modules/security_groups"
  }

  assert {
    condition     = [for r in values(aws_vpc_security_group_egress_rule.engine) : [r.cidr_ipv4, r.from_port, r.to_port]] == [["0.0.0.0/0", 443, 443]]
    error_message = "By default the engine may reach HTTPS anywhere, and nothing else but the database."
  }
}

run "egress_rules_replace_the_default" {
  command = plan

  module {
    source = "./modules/security_groups"
  }

  variables {
    egress_rules = {
      endpoints = { port = 443, cidr_blocks = ["10.0.0.0/16"] }
      hl7       = { port = 2575, cidr_blocks = ["10.30.0.0/24", "10.31.0.0/24"] }
    }
  }

  assert {
    condition = toset([for r in values(aws_vpc_security_group_egress_rule.engine) : "${r.cidr_ipv4}:${r.from_port}"]) == toset([
      "10.0.0.0/16:443", "10.30.0.0/24:2575", "10.31.0.0/24:2575",
    ])
    error_message = "egress_rules replaces the default: one rule per port and CIDR block."
  }
}

run "no_allowed_cidr_block_is_refused" {
  command = plan

  module {
    source = "./modules/security_groups"
  }

  variables {
    allowed_cidr_blocks = []
  }

  expect_failures = [var.allowed_cidr_blocks]
}
