# The cluster, two task definitions and one service.
#
# The engine task runs `pathways start --no-migrate`: it applies no schema step, and refuses a
# database that lacks one it needs. The schema moves only through the migrate task definition, which
# runs `pathways migrate`. ECS RunTask cannot override a container's image, so the migrate task
# definition has its own, migrate_image: your CI applies the new image there first, runs the migrate
# task with RunTask and waits for it to exit 0, and only then applies the new image to the service.
# There is no Terraform provisioner: a plan or an apply never runs a task.
#
# The service runs one engine. A second engine on the same database is refused by the engine lease,
# so a deploy stops the old task before it starts the new one (minimum healthy 0, maximum 100).

data "aws_region" "current" {}

locals {
  region = data.aws_region.current.region

  engine_command  = ["start", "-C", "/project", "--no-migrate"]
  migrate_command = ["migrate", "-C", "/project"]

  # The Pathways image has no shell: the health check runs the command directly. `pathways probe`
  # asks the probe listener for /livez and exits 1 when the engine is not live, so ECS replaces a
  # stalled engine. The load balancers ask /readyz.
  liveness_command = ["CMD", "/nodejs/bin/node", "/app/dist/bin/pathways.mjs", "probe", "-C", "/project"]

  container_environment = [for k in sort(keys(var.environment)) : { name = k, value = var.environment[k] }]
  container_secrets     = [for k in sort(keys(var.secrets)) : { name = k, valueFrom = var.secrets[k] }]

  # With a metrics collector the engine also reads the health endpoint's token, which the collector
  # presents; the migrate task serves no health endpoint and does not. Without one, the engine's
  # secrets are exactly var.secrets.
  engine_secrets = var.metrics_collector == null ? var.secrets : merge(var.secrets, {
    (local.health_token_variable) = var.metrics_collector.token_secret_arn
  })
  engine_container_secrets = [for k in sort(keys(local.engine_secrets)) : { name = k, valueFrom = local.engine_secrets[k] }]

  health_token_variable     = "PATHWAYS_HEALTH_TOKEN"
  collector_config_variable = "PATHWAYS_COLLECTOR_CONFIG"

  repository_credentials = var.repository_credentials_secret_arn == null ? {} : {
    repositoryCredentials = { credentialsParameter = var.repository_credentials_secret_arn }
  }

  engine_container = merge({
    name        = "engine"
    image       = var.image
    essential   = true
    command     = local.engine_command
    environment = local.container_environment
    secrets     = local.engine_container_secrets
    portMappings = [
      for p in var.container_ports : { containerPort = p, hostPort = p, protocol = "tcp" }
    ]
    stopTimeout = var.drain_timeout_seconds
    healthCheck = {
      command     = local.liveness_command
      interval    = 30
      timeout     = 10
      retries     = 3
      startPeriod = 60
    }
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = var.engine_log_group_name
        awslogs-region        = local.region
        awslogs-stream-prefix = "engine"
      }
    }
  }, local.repository_credentials)

  migrate_container = merge({
    name        = "migrate"
    image       = var.migrate_image != null ? var.migrate_image : var.image
    essential   = true
    command     = local.migrate_command
    environment = local.container_environment
    secrets     = local.container_secrets
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = var.migrate_log_group_name
        awslogs-region        = local.region
        awslogs-stream-prefix = "migrate"
      }
    }
  }, local.repository_credentials)

  # The metrics collector, beside the engine in its task: it reads its configuration from
  # PATHWAYS_COLLECTOR_CONFIG and the health token from PATHWAYS_HEALTH_TOKEN, scrapes the engine's
  # /metrics over the task's loopback, and logs to the engine's log group under its own stream
  # prefix. It is not essential, so the engine runs on if it stops; it maps no port.
  metrics_collector_container = var.metrics_collector == null ? null : {
    name      = "metrics-collector"
    image     = var.metrics_collector.image
    essential = false
    command   = ["--config=env:${local.collector_config_variable}"]
    environment = [
      { name = local.collector_config_variable, value = var.metrics_collector.config },
    ]
    secrets = [
      { name = local.health_token_variable, valueFrom = var.metrics_collector.token_secret_arn },
    ]
    dependsOn = [
      { containerName = "engine", condition = "START" },
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = var.engine_log_group_name
        awslogs-region        = local.region
        awslogs-stream-prefix = "metrics-collector"
      }
    }
  }

  # The engine's task: the engine alone, as it always was, unless a collector is given.
  engine_task_container_definitions = (
    var.metrics_collector == null
    ? jsonencode([local.engine_container])
    : jsonencode([local.engine_container, local.metrics_collector_container])
  )
}

resource "aws_ecs_cluster" "this" {
  name = "pathways-${var.name}"

  setting {
    name  = "containerInsights"
    value = var.container_insights ? "enabled" : "disabled"
  }

  tags = var.tags
}

resource "aws_ecs_task_definition" "engine" {
  family                   = "pathways-${var.name}-engine"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = tostring(var.cpu)
  memory                   = tostring(var.memory)
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.task_role_arn
  container_definitions    = local.engine_task_container_definitions

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = var.cpu_architecture
  }

  tags = var.tags
}

resource "aws_ecs_task_definition" "migrate" {
  family                   = "pathways-${var.name}-migrate"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = tostring(var.cpu)
  memory                   = tostring(var.memory)
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.task_role_arn
  container_definitions    = jsonencode([local.migrate_container])

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = var.cpu_architecture
  }

  tags = var.tags
}

resource "aws_ecs_service" "engine" {
  name             = "pathways-${var.name}-engine"
  cluster          = aws_ecs_cluster.this.id
  task_definition  = aws_ecs_task_definition.engine.arn
  launch_type      = "FARGATE"
  platform_version = "LATEST"

  # One engine per database, as the engine lease enforces. Raise cpu and memory to scale it up.
  desired_count                      = 1
  deployment_minimum_healthy_percent = 0
  deployment_maximum_percent         = 100

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  # ECS refuses a grace period on a service with no load balancer.
  health_check_grace_period_seconds = length(var.load_balancers) > 0 ? var.health_check_grace_period_seconds : null

  enable_execute_command  = false
  enable_ecs_managed_tags = true
  propagate_tags          = "SERVICE"

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = var.security_group_ids
    assign_public_ip = false
  }

  # Each target group must already be attached to its load balancer by a listener: pass target
  # group ARNs that are read after the listeners exist, as the load_balancers module's outputs are.
  dynamic "load_balancer" {
    for_each = var.load_balancers
    content {
      target_group_arn = load_balancer.value.target_group_arn
      container_name   = "engine"
      container_port   = load_balancer.value.container_port
    }
  }

  tags = var.tags
}
