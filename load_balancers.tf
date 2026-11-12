# A network load balancer for the MLLP sources and an application load balancer for the HTTP
# sources, each only when there is a source of its kind. Both are internal by default.
#
# Both check each engine's readiness, GET /readyz on the probe listener, so they send traffic only
# to an engine that holds the lease, has its storage and has its sources up.
#
# When ECS stops an engine it first deregisters it from the target groups, and the load balancers
# stop sending it new connections. They wait drain_timeout_seconds (the deregistration delay) for
# the open ones to finish, close those still open, and only then does ECS send SIGTERM. The engine
# turns not ready, closes its sources and finishes what it is storing, with drain_timeout_seconds
# more (the container's stop timeout) before SIGKILL.

locals {
  readiness_check = {
    protocol            = "HTTP"
    port                = tostring(var.probe_port)
    path                = "/readyz"
    matcher             = "200"
    interval            = 10
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

# ---------------------------------------------------------------------------
# MLLP: TCP passed through to the engine, which terminates its own TLS
# ---------------------------------------------------------------------------

resource "aws_lb" "nlb" {
  count = local.create_nlb ? 1 : 0

  name                             = "${var.name}-nlb"
  load_balancer_type               = "network"
  internal                         = var.load_balancer_internal
  subnets                          = local.load_balancer_subnet_ids
  security_groups                  = [aws_security_group.nlb[0].id]
  enable_cross_zone_load_balancing = true
  enable_deletion_protection       = var.deletion_protection
  tags                             = local.tags
}

resource "aws_lb_target_group" "mllp" {
  for_each = var.mllp_sources

  name        = "${var.name}-m${each.value.port}"
  port        = each.value.port
  protocol    = "TCP"
  target_type = "ip"
  vpc_id      = var.vpc_id

  deregistration_delay   = var.drain_timeout_seconds
  connection_termination = true
  # The engine sees the load balancer's address, so its security group can name the load
  # balancer's rather than every sender's network.
  preserve_client_ip = "false"

  health_check {
    enabled             = true
    protocol            = local.readiness_check.protocol
    port                = local.readiness_check.port
    path                = local.readiness_check.path
    matcher             = local.readiness_check.matcher
    interval            = local.readiness_check.interval
    timeout             = local.readiness_check.timeout
    healthy_threshold   = local.readiness_check.healthy_threshold
    unhealthy_threshold = local.readiness_check.unhealthy_threshold
  }

  tags = merge(local.tags, { "pathways:source" = each.key })
}

resource "aws_lb_listener" "mllp" {
  for_each = var.mllp_sources

  load_balancer_arn = aws_lb.nlb[0].arn
  port              = each.value.port
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.mllp[each.key].arn
  }

  tags = merge(local.tags, { "pathways:source" = each.key })
}

# ---------------------------------------------------------------------------
# HTTP: HTTPS at the load balancer, forwarded to the engine's HTTP sources
# ---------------------------------------------------------------------------

resource "aws_lb" "alb" {
  count = local.create_alb ? 1 : 0

  name                       = "${var.name}-alb"
  load_balancer_type         = "application"
  internal                   = var.load_balancer_internal
  subnets                    = local.load_balancer_subnet_ids
  security_groups            = [aws_security_group.alb[0].id]
  drop_invalid_header_fields = true
  enable_deletion_protection = var.deletion_protection
  tags                       = local.tags
}

resource "aws_lb_target_group" "http" {
  for_each = var.http_sources

  name             = "${var.name}-h${each.value.port}"
  port             = each.value.port
  protocol         = var.http_target_protocol
  protocol_version = "HTTP1"
  target_type      = "ip"
  vpc_id           = var.vpc_id

  deregistration_delay = var.drain_timeout_seconds

  health_check {
    enabled             = true
    protocol            = local.readiness_check.protocol
    port                = local.readiness_check.port
    path                = local.readiness_check.path
    matcher             = local.readiness_check.matcher
    interval            = local.readiness_check.interval
    timeout             = local.readiness_check.timeout
    healthy_threshold   = local.readiness_check.healthy_threshold
    unhealthy_threshold = local.readiness_check.unhealthy_threshold
  }

  tags = merge(local.tags, { "pathways:source" = each.key })
}

resource "aws_lb_listener" "http" {
  for_each = var.http_sources

  load_balancer_arn = aws_lb.alb[0].arn
  port              = each.value.port
  protocol          = "HTTPS"
  ssl_policy        = var.alb_ssl_policy
  certificate_arn   = var.alb_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.http[each.key].arn
  }

  tags = merge(local.tags, { "pathways:source" = each.key })
}
