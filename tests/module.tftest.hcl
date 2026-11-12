# Plan-only tests of the module. Every run block is `command = plan` against a mocked aws provider:
# no credentials, no API call, no state, nothing created. tests/run.sh refuses a run block that does
# not say `command = plan` and a file that does not mock aws.
#
# Every value is synthetic: the documentation account id 123456789012, ids of zeros and counting
# digits, names on example.com, and an image digest of zeros.

mock_provider "aws" {
  override_during = plan

  # A mocked policy document still has to be valid JSON: the roles and the key read it. The
  # statements themselves are asserted on the data sources' arguments below.
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
}

variables {
  name                = "test"
  vpc_id              = "vpc-00000000000000000"
  private_subnet_ids  = ["subnet-00000000000000001", "subnet-00000000000000002"]
  allowed_cidr_blocks = ["10.20.0.0/16"]
  image               = "registry.example.com/integration/project:1@sha256:0000000000000000000000000000000000000000000000000000000000000000"
  mllp_sources = {
    adt = { port = 2575 }
  }
}

# ---------------------------------------------------------------------------
# Secure by default
# ---------------------------------------------------------------------------

run "database_is_encrypted_private_and_forces_tls" {
  command = plan

  assert {
    condition     = aws_db_instance.this.storage_encrypted && aws_db_instance.this.kms_key_id == aws_kms_key.this.arn
    error_message = "The database's storage must be encrypted under the module's key."
  }

  assert {
    condition     = aws_db_instance.this.publicly_accessible == false
    error_message = "The database must not be publicly accessible."
  }

  assert {
    condition     = anytrue([for p in aws_db_parameter_group.this.parameter : p.name == "rds.force_ssl" && p.value == "1"])
    error_message = "The database must refuse connections without TLS (rds.force_ssl = 1)."
  }

  assert {
    condition     = aws_db_instance.this.engine == "postgres" && aws_db_instance.this.deletion_protection && !aws_db_instance.this.skip_final_snapshot
    error_message = "The database must be PostgreSQL, protected from deletion, with a final snapshot."
  }

  assert {
    condition     = aws_db_instance.this.performance_insights_enabled == false
    error_message = "Performance Insights keeps statement text: it stays off."
  }

  assert {
    condition = [
      for r in aws_vpc_security_group_ingress_rule.database_from_engine[*] : r.referenced_security_group_id
    ] == [aws_security_group.engine.id]
    error_message = "Only the engine's security group may reach the database."
  }
}

run "key_rotates_and_encrypts_secret_and_logs" {
  command = plan

  assert {
    condition     = aws_kms_key.this.enable_key_rotation
    error_message = "The module's KMS key must rotate."
  }

  assert {
    condition     = aws_secretsmanager_secret.database_url.kms_key_id == aws_kms_key.this.arn
    error_message = "The database URL secret must be encrypted under the module's key."
  }

  assert {
    condition = alltrue([
      for g in [aws_cloudwatch_log_group.engine, aws_cloudwatch_log_group.migrate] :
      g.kms_key_id == aws_kms_key.this.arn && g.retention_in_days == 365
    ])
    error_message = "Both log groups must be encrypted under the module's key and keep logs for log_retention_days."
  }

  assert {
    condition = anytrue([
      for s in data.aws_iam_policy_document.kms.statement :
      contains(flatten([for p in s.principals : tolist(p.identifiers)]), "logs.us-east-1.amazonaws.com")
      && anytrue([for c in s.condition : c.variable == "kms:EncryptionContext:aws:logs:arn" && contains(c.values, "arn:aws:logs:us-east-1:123456789012:log-group:/pathways/test/*")])
    ])
    error_message = "CloudWatch Logs may use the key only for this deployment's log groups."
  }
}

run "nlb_passes_mllp_through_and_checks_readiness" {
  command = plan

  assert {
    condition     = aws_lb.nlb[0].load_balancer_type == "network" && aws_lb.nlb[0].internal
    error_message = "MLLP sources need an internal network load balancer."
  }

  assert {
    condition     = aws_lb_listener.mllp["adt"].protocol == "TCP" && aws_lb_listener.mllp["adt"].port == 2575
    error_message = "Each MLLP source gets a TCP listener on its port: the engine terminates its own TLS."
  }

  assert {
    condition     = aws_lb_target_group.mllp["adt"].protocol == "TCP" && aws_lb_target_group.mllp["adt"].target_type == "ip"
    error_message = "The MLLP target group must pass TCP to the tasks' addresses."
  }

  assert {
    condition = (
      aws_lb_target_group.mllp["adt"].health_check[0].protocol == "HTTP"
      && aws_lb_target_group.mllp["adt"].health_check[0].path == "/readyz"
      && aws_lb_target_group.mllp["adt"].health_check[0].port == "9091"
      && aws_lb_target_group.mllp["adt"].health_check[0].matcher == "200"
    )
    error_message = "Target health must be GET /readyz on the probe port."
  }

  assert {
    condition     = length(aws_lb.alb) == 0 && length(aws_lb_listener.http) == 0
    error_message = "No HTTP source, no application load balancer."
  }

  assert {
    condition     = [for r in values(aws_vpc_security_group_ingress_rule.nlb) : r.cidr_ipv4] == ["10.20.0.0/16"]
    error_message = "The network load balancer admits allowed_cidr_blocks only."
  }
}

# ---------------------------------------------------------------------------
# The engine and its drain
# ---------------------------------------------------------------------------

run "engine_task_runs_start_without_migrating" {
  command = plan

  assert {
    condition     = jsondecode(aws_ecs_task_definition.engine.container_definitions)[0].command == ["start", "-C", "/project", "--no-migrate"]
    error_message = "The engine runs pathways start --no-migrate: the schema moves only through the migrate task."
  }

  assert {
    condition     = jsondecode(aws_ecs_task_definition.engine.container_definitions)[0].image == var.image
    error_message = "The engine runs the image named by digest."
  }

  assert {
    condition = contains(
      jsondecode(aws_ecs_task_definition.engine.container_definitions)[0].healthCheck.command,
      "probe",
    )
    error_message = "The container health check is pathways probe, which asks /livez."
  }

  assert {
    condition = (
      aws_ecs_task_definition.engine.cpu == "1024"
      && aws_ecs_task_definition.engine.memory == "2048"
      && aws_ecs_task_definition.engine.requires_compatibilities == toset(["FARGATE"])
    )
    error_message = "The engine task is a Fargate task of the size cpu and memory say."
  }
}

run "secrets_are_injected_never_plain" {
  command = plan

  variables {
    environment = { PATHWAYS_STORAGE = "postgres" }
    secrets     = { PATHWAYS_KEY_2026_11 = "arn:aws:secretsmanager:us-east-1:123456789012:secret:test/master-key-AbCdEf:key::" }
  }

  assert {
    condition = jsondecode(aws_ecs_task_definition.engine.container_definitions)[0].secrets == [
      { name = "PATHWAYS_DATABASE_URL", valueFrom = aws_secretsmanager_secret.database_url.arn },
      { name = "PATHWAYS_KEY_2026_11", valueFrom = "arn:aws:secretsmanager:us-east-1:123456789012:secret:test/master-key-AbCdEf:key::" },
    ]
    error_message = "The database URL and the caller's secrets are injected through secrets, valueFrom their ARNs."
  }

  assert {
    condition = jsondecode(aws_ecs_task_definition.engine.container_definitions)[0].environment == [
      { name = "PATHWAYS_STORAGE", value = "postgres" },
    ]
    error_message = "Only the plain settings are in environment."
  }

  assert {
    condition     = jsondecode(aws_ecs_task_definition.migrate.container_definitions)[0].secrets == jsondecode(aws_ecs_task_definition.engine.container_definitions)[0].secrets
    error_message = "The migrate task reads the same secrets, so it loads the same pathways.yaml."
  }

  assert {
    condition = anytrue([
      for s in data.aws_iam_policy_document.execution.statement :
      s.sid == "ReadSecrets" && toset(s.resources) == toset([
        aws_secretsmanager_secret.database_url.arn,
        "arn:aws:secretsmanager:us-east-1:123456789012:secret:test/master-key-AbCdEf",
      ])
    ])
    error_message = "The execution role reads exactly the injected secrets, named by their ARNs without the JSON key."
  }
}

run "drain_sets_stop_timeout_and_deregistration_delay" {
  command = plan

  variables {
    drain_timeout_seconds = 90
  }

  assert {
    condition     = jsondecode(aws_ecs_task_definition.engine.container_definitions)[0].stopTimeout == 90
    error_message = "The container's stop timeout is drain_timeout_seconds."
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

run "drain_over_fargate_maximum_is_refused" {
  command = plan

  variables {
    drain_timeout_seconds = 121
  }

  expect_failures = [var.drain_timeout_seconds]
}

run "service_runs_one_engine_privately" {
  command = plan

  assert {
    condition     = aws_ecs_service.engine.desired_count == 1
    error_message = "One engine runs per database."
  }

  assert {
    condition = (
      aws_ecs_service.engine.deployment_minimum_healthy_percent == 0
      && aws_ecs_service.engine.deployment_maximum_percent == 100
    )
    error_message = "A deploy stops the old engine before it starts the new one: the engine lease refuses a second."
  }

  assert {
    condition = (
      aws_ecs_service.engine.network_configuration[0].assign_public_ip == false
      && aws_ecs_service.engine.network_configuration[0].security_groups == toset([aws_security_group.engine.id])
    )
    error_message = "The engine's tasks get no public address and sit in the engine's security group."
  }

  assert {
    condition     = aws_ecs_service.engine.enable_execute_command == false
    error_message = "ECS Exec stays off: no shell into a task that holds PHI."
  }

  assert {
    condition     = one([for lb in aws_ecs_service.engine.load_balancer : lb.container_port]) == 2575
    error_message = "The service registers the engine's MLLP port with its target group."
  }
}

run "migrate_task_runs_pathways_migrate" {
  command = plan

  assert {
    condition     = jsondecode(aws_ecs_task_definition.migrate.container_definitions)[0].command == ["migrate", "-C", "/project"]
    error_message = "The migrate task runs pathways migrate."
  }

  assert {
    condition     = !can(jsondecode(aws_ecs_task_definition.migrate.container_definitions)[0].portMappings)
    error_message = "The migrate task listens on nothing."
  }

  assert {
    condition = (
      jsondecode(output.migrate_network_configuration).awsvpcConfiguration.assignPublicIp == "DISABLED"
      && jsondecode(output.migrate_network_configuration).awsvpcConfiguration.securityGroups == [aws_security_group.engine.id]
    )
    error_message = "The migrate RunTask runs privately, in the security group the database admits."
  }
}

run "migrate_image_moves_the_migrate_task_alone" {
  command = plan

  variables {
    migrate_image = "registry.example.com/integration/project:2@sha256:1111111111111111111111111111111111111111111111111111111111111111"
  }

  assert {
    condition     = jsondecode(aws_ecs_task_definition.migrate.container_definitions)[0].image == var.migrate_image
    error_message = "The migrate task runs migrate_image when it is set."
  }

  assert {
    condition     = jsondecode(aws_ecs_task_definition.engine.container_definitions)[0].image == var.image
    error_message = "migrate_image does not move the engine: that waits for the migrate task to succeed."
  }
}

run "migrate_image_by_tag_alone_is_refused" {
  command = plan

  variables {
    migrate_image = "registry.example.com/integration/project:2"
  }

  expect_failures = [var.migrate_image]
}

# ---------------------------------------------------------------------------
# HTTP sources
# ---------------------------------------------------------------------------

run "http_sources_get_an_https_alb" {
  command = plan

  variables {
    http_sources        = { orders = { port = 8443 } }
    alb_certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/00000000-0000-0000-0000-000000000000"
  }

  assert {
    condition     = aws_lb.alb[0].load_balancer_type == "application" && aws_lb.alb[0].internal && aws_lb.alb[0].drop_invalid_header_fields
    error_message = "HTTP sources need an internal application load balancer that drops invalid headers."
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
    condition     = length(aws_ecs_service.engine.load_balancer) == 2
    error_message = "The service registers both sources."
  }
}

run "http_sources_without_a_certificate_are_refused" {
  command = plan

  variables {
    http_sources = { orders = { port = 8443 } }
  }

  expect_failures = [var.alb_certificate_arn]
}

run "no_sources_no_load_balancers" {
  command = plan

  variables {
    mllp_sources = {}
  }

  assert {
    condition     = length(aws_lb.nlb) == 0 && length(aws_lb.alb) == 0 && length(aws_ecs_service.engine.load_balancer) == 0
    error_message = "With no source there is no load balancer."
  }

  assert {
    condition     = aws_ecs_service.engine.health_check_grace_period_seconds == null
    error_message = "ECS refuses a health check grace period on a service with no load balancer."
  }
}

# ---------------------------------------------------------------------------
# Inputs refused
# ---------------------------------------------------------------------------

run "image_by_tag_alone_is_refused" {
  command = plan

  variables {
    image = "registry.example.com/integration/project:1"
  }

  expect_failures = [var.image]
}

run "shared_port_is_refused" {
  command = plan

  variables {
    mllp_sources = { adt = { port = 9091 } }
  }

  expect_failures = [var.probe_port]
}

run "database_url_from_caller_is_refused" {
  command = plan

  variables {
    secrets = { PATHWAYS_DATABASE_URL = "arn:aws:secretsmanager:us-east-1:123456789012:secret:test/url-AbCdEf" }
  }

  expect_failures = [var.secrets]
}

run "name_in_environment_and_secrets_is_refused" {
  command = plan

  variables {
    environment = { PATHWAYS_KEY = "plain" }
    secrets     = { PATHWAYS_KEY = "arn:aws:secretsmanager:us-east-1:123456789012:secret:test/key-AbCdEf" }
  }

  expect_failures = [var.secrets]
}

run "more_than_five_sources_is_refused" {
  command = plan

  variables {
    mllp_sources = {
      a = { port = 2575 }
      b = { port = 2576 }
      c = { port = 2577 }
      d = { port = 2578 }
      e = { port = 2579 }
      f = { port = 2580 }
    }
  }

  expect_failures = [var.http_sources]
}

# ---------------------------------------------------------------------------
# Image registry access
# ---------------------------------------------------------------------------

run "ecr_image_reads_its_own_repository_only" {
  command = plan

  variables {
    image = "123456789012.dkr.ecr.us-east-1.amazonaws.com/integration/project@sha256:0000000000000000000000000000000000000000000000000000000000000000"
  }

  assert {
    condition = anytrue([
      for s in data.aws_iam_policy_document.execution.statement :
      s.sid == "PullImage" && toset(s.resources) == toset(["arn:aws:ecr:us-east-1:123456789012:repository/integration/project"])
    ])
    error_message = "An ECR image gives the execution role its own repository, and no other."
  }
}

run "image_outside_ecr_reads_no_ecr" {
  command = plan

  assert {
    condition     = length([for s in data.aws_iam_policy_document.execution.statement : s if startswith(coalesce(s.sid, "none"), "Ecr") || coalesce(s.sid, "none") == "PullImage"]) == 0
    error_message = "An image outside ECR gives the execution role no ECR permission."
  }
}

# ---------------------------------------------------------------------------
# The database password, its key, and what the cluster captures
# ---------------------------------------------------------------------------

run "container_insights_off_by_default" {
  command = plan

  assert {
    condition     = anytrue([for s in aws_ecs_cluster.this.setting : s.name == "containerInsights" && s.value == "disabled"])
    error_message = "Container Insights is off unless asked for: its log group is not under the module's key."
  }
}

run "container_insights_on_when_asked" {
  command = plan

  variables {
    container_insights = true
  }

  assert {
    condition     = anytrue([for s in aws_ecs_cluster.this.setting : s.name == "containerInsights" && s.value == "enabled"])
    error_message = "container_insights = true turns Container Insights on."
  }
}

run "raising_password_version_rotates_password_and_url" {
  command = plan

  variables {
    database_password_version = 2
  }

  assert {
    condition     = aws_db_instance.this.password_wo_version == 2
    error_message = "Raising database_password_version sets a new password on the database."
  }

  assert {
    condition     = aws_secretsmanager_secret_version.database_url.secret_string_wo_version == 2
    error_message = "Raising database_password_version writes a new connection URL to the secret in the same run."
  }
}

run "database_key_from_caller_outlives_the_module" {
  command = plan

  variables {
    database_kms_key_arn = "arn:aws:kms:us-east-1:123456789012:key/11111111-1111-1111-1111-111111111111"
  }

  assert {
    condition     = aws_db_instance.this.storage_encrypted && aws_db_instance.this.kms_key_id == "arn:aws:kms:us-east-1:123456789012:key/11111111-1111-1111-1111-111111111111"
    error_message = "With database_kms_key_arn set, the database and its snapshots are encrypted under the caller's key."
  }

  assert {
    condition     = aws_secretsmanager_secret.database_url.kms_key_id == aws_kms_key.this.arn
    error_message = "The secret stays under the module's key."
  }
}

run "database_key_that_is_not_a_kms_key_arn_is_refused" {
  command = plan

  variables {
    database_kms_key_arn = "alias/pathways-test"
  }

  expect_failures = [var.database_kms_key_arn]
}
