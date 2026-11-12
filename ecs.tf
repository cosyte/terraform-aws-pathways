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

locals {
  engine_command  = ["start", "-C", "/project", "--no-migrate"]
  migrate_command = ["migrate", "-C", "/project"]

  # The Pathways image has no shell: the health check runs the command directly. `pathways probe`
  # asks the probe listener for /livez and exits 1 when the engine is not live, so ECS replaces a
  # stalled engine. The load balancers ask /readyz.
  liveness_command = ["CMD", "/nodejs/bin/node", "/app/dist/bin/pathways.mjs", "probe", "-C", "/project"]

  container_environment = [for k in sort(keys(var.environment)) : { name = k, value = var.environment[k] }]
  container_secrets     = [for k in sort(keys(local.task_secrets)) : { name = k, valueFrom = local.task_secrets[k] }]

  repository_credentials = var.repository_credentials_secret_arn == null ? {} : {
    repositoryCredentials = { credentialsParameter = var.repository_credentials_secret_arn }
  }

  engine_container = merge({
    name        = "engine"
    image       = var.image
    essential   = true
    command     = local.engine_command
    environment = local.container_environment
    secrets     = local.container_secrets
    portMappings = [
      for p in local.container_ports : { containerPort = p, hostPort = p, protocol = "tcp" }
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
        awslogs-group         = aws_cloudwatch_log_group.engine.name
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
        awslogs-group         = aws_cloudwatch_log_group.migrate.name
        awslogs-region        = local.region
        awslogs-stream-prefix = "migrate"
      }
    }
  }, local.repository_credentials)
}

resource "aws_ecs_cluster" "this" {
  name = "pathways-${var.name}"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = local.tags
}

resource "aws_ecs_task_definition" "engine" {
  family                   = "pathways-${var.name}-engine"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = tostring(var.cpu)
  memory                   = tostring(var.memory)
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn
  container_definitions    = jsonencode([local.engine_container])

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = var.cpu_architecture
  }

  tags = local.tags
}

resource "aws_ecs_task_definition" "migrate" {
  family                   = "pathways-${var.name}-migrate"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = tostring(var.cpu)
  memory                   = tostring(var.memory)
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn
  container_definitions    = jsonencode([local.migrate_container])

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = var.cpu_architecture
  }

  tags = local.tags
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

  health_check_grace_period_seconds = local.create_nlb || local.create_alb ? var.health_check_grace_period_seconds : null

  enable_execute_command  = false
  enable_ecs_managed_tags = true
  propagate_tags          = "SERVICE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.engine.id]
    assign_public_ip = false
  }

  dynamic "load_balancer" {
    for_each = var.mllp_sources
    content {
      target_group_arn = aws_lb_target_group.mllp[load_balancer.key].arn
      container_name   = "engine"
      container_port   = load_balancer.value.port
    }
  }

  dynamic "load_balancer" {
    for_each = var.http_sources
    content {
      target_group_arn = aws_lb_target_group.http[load_balancer.key].arn
      container_name   = "engine"
      container_port   = load_balancer.value.port
    }
  }

  tags = local.tags

  # The listeners attach each target group to its load balancer, which ECS needs first.
  depends_on = [aws_lb_listener.mllp, aws_lb_listener.http]
}
