# Plan-only tests of modules/ecs on its own, against a mocked aws provider. Every value is synthetic:
# the documentation account id 123456789012, ids of zeros and counting digits, names on example.com,
# and an image digest of zeros.

mock_provider "aws" {
  override_during = plan

  mock_data "aws_region" {
    defaults = {
      region = "us-east-1"
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
}

variables {
  name                   = "test"
  image                  = "registry.example.com/integration/project:1@sha256:0000000000000000000000000000000000000000000000000000000000000000"
  container_ports        = [2575, 9091]
  execution_role_arn     = "arn:aws:iam::123456789012:role/pathways-test-execution"
  task_role_arn          = "arn:aws:iam::123456789012:role/pathways-test-task"
  engine_log_group_name  = "/pathways/test/engine"
  migrate_log_group_name = "/pathways/test/migrate"
  subnet_ids             = ["subnet-00000000000000001", "subnet-00000000000000002"]
  security_group_ids     = ["sg-00000000000000001"]
  load_balancers = {
    mllp-adt = {
      target_group_arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/test/0123456789abcdef"
      container_port   = 2575
    }
  }
}

# ---------------------------------------------------------------------------
# The engine task
# ---------------------------------------------------------------------------

run "engine_task_runs_start_without_migrating" {
  command = plan

  module {
    source = "./modules/ecs"
  }

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

  assert {
    condition = (
      aws_ecs_task_definition.engine.execution_role_arn == var.execution_role_arn
      && aws_ecs_task_definition.engine.task_role_arn == var.task_role_arn
    )
    error_message = "The engine task starts with the execution role and runs as the task role."
  }

  assert {
    condition     = [for p in jsondecode(aws_ecs_task_definition.engine.container_definitions)[0].portMappings : p.containerPort] == [2575, 9091]
    error_message = "The engine listens on container_ports."
  }

  assert {
    condition     = jsondecode(aws_ecs_task_definition.engine.container_definitions)[0].logConfiguration.options == { awslogs-group = "/pathways/test/engine", awslogs-region = "us-east-1", awslogs-stream-prefix = "engine" }
    error_message = "The engine logs through awslogs to its group, in the provider's region."
  }
}

run "secrets_are_injected_never_plain" {
  command = plan

  module {
    source = "./modules/ecs"
  }

  variables {
    environment = { PATHWAYS_STORAGE = "postgres" }
    secrets     = { PATHWAYS_KEY_2026_11 = "arn:aws:secretsmanager:us-east-1:123456789012:secret:test/master-key-AbCdEf:key::" }
  }

  assert {
    condition = jsondecode(aws_ecs_task_definition.engine.container_definitions)[0].secrets == [
      { name = "PATHWAYS_KEY_2026_11", valueFrom = "arn:aws:secretsmanager:us-east-1:123456789012:secret:test/master-key-AbCdEf:key::" },
    ]
    error_message = "The secrets are injected through secrets, valueFrom their ARNs."
  }

  assert {
    condition     = jsondecode(aws_ecs_task_definition.engine.container_definitions)[0].environment == [{ name = "PATHWAYS_STORAGE", value = "postgres" }]
    error_message = "Only the plain settings are in environment."
  }

  assert {
    condition     = jsondecode(aws_ecs_task_definition.migrate.container_definitions)[0].secrets == jsondecode(aws_ecs_task_definition.engine.container_definitions)[0].secrets
    error_message = "The migrate task reads the same secrets, so it loads the same pathways.yaml."
  }
}

run "registry_credentials_reach_both_containers" {
  command = plan

  module {
    source = "./modules/ecs"
  }

  variables {
    repository_credentials_secret_arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:test/registry-AbCdEf"
  }

  assert {
    condition = alltrue([
      for c in [output.engine_container, output.migrate_container] :
      c.repositoryCredentials.credentialsParameter == "arn:aws:secretsmanager:us-east-1:123456789012:secret:test/registry-AbCdEf"
    ])
    error_message = "Both containers pull with the private registry's credentials."
  }
}

run "drain_sets_the_stop_timeout" {
  command = plan

  module {
    source = "./modules/ecs"
  }

  variables {
    drain_timeout_seconds = 90
  }

  assert {
    condition     = jsondecode(aws_ecs_task_definition.engine.container_definitions)[0].stopTimeout == 90
    error_message = "The container's stop timeout is drain_timeout_seconds."
  }
}

# ---------------------------------------------------------------------------
# The service
# ---------------------------------------------------------------------------

run "service_runs_one_engine_privately" {
  command = plan

  module {
    source = "./modules/ecs"
  }

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
      && aws_ecs_service.engine.network_configuration[0].security_groups == toset(["sg-00000000000000001"])
    )
    error_message = "The engine's tasks get no public address and sit in the security groups given."
  }

  assert {
    condition     = aws_ecs_service.engine.enable_execute_command == false
    error_message = "ECS Exec stays off: no shell into a task that holds PHI."
  }

  assert {
    condition     = one([for lb in aws_ecs_service.engine.load_balancer : lb.container_port]) == 2575
    error_message = "The service registers the engine's MLLP port with its target group."
  }

  assert {
    condition     = aws_ecs_service.engine.health_check_grace_period_seconds == 120
    error_message = "With a load balancer, ECS waits the grace period before it acts on health checks."
  }
}

run "no_load_balancer_no_grace_period" {
  command = plan

  module {
    source = "./modules/ecs"
  }

  variables {
    load_balancers = {}
  }

  assert {
    condition     = length(aws_ecs_service.engine.load_balancer) == 0 && aws_ecs_service.engine.health_check_grace_period_seconds == null
    error_message = "ECS refuses a health check grace period on a service with no load balancer."
  }
}

run "container_insights_off_by_default" {
  command = plan

  module {
    source = "./modules/ecs"
  }

  assert {
    condition     = anytrue([for s in aws_ecs_cluster.this.setting : s.name == "containerInsights" && s.value == "disabled"])
    error_message = "Container Insights is off unless asked for: its log group is not under the deployment's key."
  }
}

run "container_insights_on_when_asked" {
  command = plan

  module {
    source = "./modules/ecs"
  }

  variables {
    container_insights = true
  }

  assert {
    condition     = anytrue([for s in aws_ecs_cluster.this.setting : s.name == "containerInsights" && s.value == "enabled"])
    error_message = "container_insights = true turns Container Insights on."
  }
}

# ---------------------------------------------------------------------------
# The migrate task
# ---------------------------------------------------------------------------

run "migrate_task_runs_pathways_migrate" {
  command = plan

  module {
    source = "./modules/ecs"
  }

  assert {
    condition     = jsondecode(aws_ecs_task_definition.migrate.container_definitions)[0].command == ["migrate", "-C", "/project"]
    error_message = "The migrate task runs pathways migrate."
  }

  assert {
    condition     = !can(jsondecode(aws_ecs_task_definition.migrate.container_definitions)[0].portMappings)
    error_message = "The migrate task listens on nothing."
  }

  assert {
    condition     = jsondecode(aws_ecs_task_definition.migrate.container_definitions)[0].image == var.image
    error_message = "With no migrate_image the migrate task runs image."
  }
}

run "migrate_image_moves_the_migrate_task_alone" {
  command = plan

  module {
    source = "./modules/ecs"
  }

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

# ---------------------------------------------------------------------------
# Inputs refused
# ---------------------------------------------------------------------------

run "image_by_tag_alone_is_refused" {
  command = plan

  module {
    source = "./modules/ecs"
  }

  variables {
    image = "registry.example.com/integration/project:1"
  }

  expect_failures = [var.image]
}

run "drain_over_fargate_maximum_is_refused" {
  command = plan

  module {
    source = "./modules/ecs"
  }

  variables {
    drain_timeout_seconds = 121
  }

  expect_failures = [var.drain_timeout_seconds]
}

run "load_balancer_on_a_port_the_engine_does_not_listen_on_is_refused" {
  command = plan

  module {
    source = "./modules/ecs"
  }

  variables {
    container_ports = [9091]
  }

  expect_failures = [var.load_balancers]
}

run "more_than_five_load_balancers_is_refused" {
  command = plan

  module {
    source = "./modules/ecs"
  }

  variables {
    container_ports = [2575, 2576, 2577, 2578, 2579, 2580]
    load_balancers = {
      a = { target_group_arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/a/0123456789abcdef", container_port = 2575 }
      b = { target_group_arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/b/0123456789abcdef", container_port = 2576 }
      c = { target_group_arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/c/0123456789abcdef", container_port = 2577 }
      d = { target_group_arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/d/0123456789abcdef", container_port = 2578 }
      e = { target_group_arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/e/0123456789abcdef", container_port = 2579 }
      f = { target_group_arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/f/0123456789abcdef", container_port = 2580 }
    }
  }

  expect_failures = [var.load_balancers]
}

# ---------------------------------------------------------------------------
# The metrics collector, none by default
# ---------------------------------------------------------------------------

run "no_collector_by_default" {
  command = plan

  module {
    source = "./modules/ecs"
  }

  assert {
    condition     = output.engine_task_container_definitions == jsonencode([output.engine_container]) && output.metrics_collector_container == null
    error_message = "With no metrics_collector the engine's task holds the engine container alone."
  }
}

run "collector_runs_beside_the_engine_and_shares_its_token" {
  command = plan

  module {
    source = "./modules/ecs"
  }

  variables {
    secrets = { PATHWAYS_KEY_2026_11 = "arn:aws:secretsmanager:us-east-1:123456789012:secret:test/master-key-AbCdEf" }
    metrics_collector = {
      image            = "public.ecr.aws/example/collector:1@sha256:2222222222222222222222222222222222222222222222222222222222222222"
      config           = "receivers: {}"
      token_secret_arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:pathways/test/health-token-AbCdEf"
    }
  }

  assert {
    condition     = [for c in jsondecode(aws_ecs_task_definition.engine.container_definitions) : c.name] == ["engine", "metrics-collector"]
    error_message = "The engine's task runs the engine and the collector."
  }

  assert {
    condition = (
      output.metrics_collector_container.essential == false
      && output.metrics_collector_container.image == var.metrics_collector.image
      && output.metrics_collector_container.command == ["--config=env:PATHWAYS_COLLECTOR_CONFIG"]
      && output.metrics_collector_container.environment == [{ name = "PATHWAYS_COLLECTOR_CONFIG", value = "receivers: {}" }]
      && !can(output.metrics_collector_container.portMappings)
      && output.engine_task_container_definitions == jsonencode([output.engine_container, output.metrics_collector_container])
    )
    error_message = "The collector is not essential, runs the image given with its configuration from PATHWAYS_COLLECTOR_CONFIG, and maps no port."
  }

  assert {
    condition = (
      output.engine_container.secrets == [
        { name = "PATHWAYS_HEALTH_TOKEN", valueFrom = var.metrics_collector.token_secret_arn },
        { name = "PATHWAYS_KEY_2026_11", valueFrom = "arn:aws:secretsmanager:us-east-1:123456789012:secret:test/master-key-AbCdEf" },
      ]
      && output.metrics_collector_container.secrets == [
        { name = "PATHWAYS_HEALTH_TOKEN", valueFrom = var.metrics_collector.token_secret_arn },
      ]
    )
    error_message = "The engine and the collector read the health token from the same secret, by ARN; the collector gets no other secret."
  }

  assert {
    condition     = output.migrate_container.secrets == [{ name = "PATHWAYS_KEY_2026_11", valueFrom = "arn:aws:secretsmanager:us-east-1:123456789012:secret:test/master-key-AbCdEf" }]
    error_message = "The migrate task gets no health token."
  }

  assert {
    condition = (
      output.metrics_collector_container.logConfiguration.options.awslogs-group == "/pathways/test/engine"
      && output.metrics_collector_container.logConfiguration.options.awslogs-stream-prefix == "metrics-collector"
    )
    error_message = "The collector logs to the engine's log group under its own stream prefix."
  }
}

run "collector_image_by_tag_alone_is_refused" {
  command = plan

  module {
    source = "./modules/ecs"
  }

  variables {
    metrics_collector = {
      image            = "public.ecr.aws/example/collector:latest"
      config           = "receivers: {}"
      token_secret_arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:pathways/test/health-token-AbCdEf"
    }
  }

  expect_failures = [var.metrics_collector]
}

run "health_token_in_secrets_with_a_collector_is_refused" {
  command = plan

  module {
    source = "./modules/ecs"
  }

  variables {
    secrets = { PATHWAYS_HEALTH_TOKEN = "arn:aws:secretsmanager:us-east-1:123456789012:secret:test/health-token-AbCdEf" }
    metrics_collector = {
      image            = "public.ecr.aws/example/collector:1@sha256:2222222222222222222222222222222222222222222222222222222222222222"
      config           = "receivers: {}"
      token_secret_arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:pathways/test/health-token-AbCdEf"
    }
  }

  expect_failures = [var.metrics_collector]
}
