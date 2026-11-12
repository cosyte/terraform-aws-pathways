# Four security groups, each opened only as far as the next hop needs:
#
#   allowed_cidr_blocks -> network load balancer      the MLLP ports
#   allowed_cidr_blocks -> application load balancer  the HTTP ports
#   load balancers      -> engine                     their source ports and the probe port
#   engine              -> database                   5432
#
# The database's group is this module's own, unless database_security_group_id names the group of an
# existing database: then the module creates none, and adds the two rules above to that one.
#
# The engine may also reach what egress_rules lists: the AWS APIs and the destinations. A load
# balancer's group exists only when there is a source of its kind.

locals {
  create_database_group = var.database_security_group_id == null
  database_group_id     = local.create_database_group ? aws_security_group.database[0].id : var.database_security_group_id

  create_nlb = length(var.mllp_sources) > 0
  create_alb = length(var.http_sources) > 0

  # One rule per source port, keyed by the source's name, plus the probe port for each load balancer.
  nlb_to_engine = local.create_nlb ? merge(
    { for k, s in var.mllp_sources : "mllp-${k}" => s.port },
    { probe = var.probe_port },
  ) : {}
  alb_to_engine = local.create_alb ? merge(
    { for k, s in var.http_sources : "http-${k}" => s.port },
    { probe = var.probe_port },
  ) : {}

  # Each (rule, CIDR block) pair of egress_rules, and of the load balancers' ingress.
  engine_egress = merge({}, [
    for k, r in var.egress_rules : {
      for c in r.cidr_blocks : "${k}-${c}" => { port = r.port, cidr = c }
    }
  ]...)
  nlb_ingress = merge({}, [
    for k, s in var.mllp_sources : {
      for c in var.allowed_cidr_blocks : "${k}-${c}" => { port = s.port, cidr = c }
    }
  ]...)
  alb_ingress = merge({}, [
    for k, s in var.http_sources : {
      for c in var.allowed_cidr_blocks : "${k}-${c}" => { port = s.port, cidr = c }
    }
  ]...)
}

# ---------------------------------------------------------------------------
# The engine
# ---------------------------------------------------------------------------

resource "aws_security_group" "engine" {
  name        = "pathways-${var.name}-engine"
  description = "Pathways ${var.name}: the engine tasks"
  vpc_id      = var.vpc_id
  tags        = var.tags
}

resource "aws_vpc_security_group_ingress_rule" "engine_from_nlb" {
  for_each = local.nlb_to_engine

  security_group_id            = aws_security_group.engine.id
  description                  = "From the network load balancer: ${each.key}"
  referenced_security_group_id = aws_security_group.nlb[0].id
  ip_protocol                  = "tcp"
  from_port                    = each.value
  to_port                      = each.value
  tags                         = var.tags
}

resource "aws_vpc_security_group_ingress_rule" "engine_from_alb" {
  for_each = local.alb_to_engine

  security_group_id            = aws_security_group.engine.id
  description                  = "From the application load balancer: ${each.key}"
  referenced_security_group_id = aws_security_group.alb[0].id
  ip_protocol                  = "tcp"
  from_port                    = each.value
  to_port                      = each.value
  tags                         = var.tags
}

resource "aws_vpc_security_group_egress_rule" "engine_to_database" {
  security_group_id            = aws_security_group.engine.id
  description                  = "To the database"
  referenced_security_group_id = local.database_group_id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  tags                         = var.tags
}

resource "aws_vpc_security_group_egress_rule" "engine" {
  for_each = local.engine_egress

  security_group_id = aws_security_group.engine.id
  description       = "egress_rules: ${each.key}"
  # The default rule is HTTPS to anywhere: through a NAT gateway, that is how a task reaches the
  # image registry, Secrets Manager and CloudWatch Logs. A caller with VPC endpoints narrows it.
  #trivy:ignore:AVD-AWS-0104
  cidr_ipv4   = each.value.cidr
  ip_protocol = "tcp"
  from_port   = each.value.port
  to_port     = each.value.port
  tags        = var.tags
}

# ---------------------------------------------------------------------------
# The database
# ---------------------------------------------------------------------------

resource "aws_security_group" "database" {
  count = local.create_database_group ? 1 : 0

  name        = "pathways-${var.name}-database"
  description = "Pathways ${var.name}: the database, reachable from the engine only"
  vpc_id      = var.vpc_id
  tags        = var.tags
}

moved {
  from = aws_security_group.database
  to   = aws_security_group.database[0]
}

resource "aws_vpc_security_group_ingress_rule" "database_from_engine" {
  security_group_id            = local.database_group_id
  description                  = "From the engine"
  referenced_security_group_id = aws_security_group.engine.id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  tags                         = var.tags
}

# ---------------------------------------------------------------------------
# The load balancers
# ---------------------------------------------------------------------------

resource "aws_security_group" "nlb" {
  count = local.create_nlb ? 1 : 0

  name        = "pathways-${var.name}-nlb"
  description = "Pathways ${var.name}: the network load balancer for the MLLP sources"
  vpc_id      = var.vpc_id
  tags        = var.tags
}

resource "aws_vpc_security_group_ingress_rule" "nlb" {
  for_each = local.nlb_ingress

  security_group_id = aws_security_group.nlb[0].id
  description       = "MLLP source ${each.key}"
  cidr_ipv4         = each.value.cidr
  ip_protocol       = "tcp"
  from_port         = each.value.port
  to_port           = each.value.port
  tags              = var.tags
}

resource "aws_vpc_security_group_egress_rule" "nlb_to_engine" {
  for_each = local.nlb_to_engine

  security_group_id            = aws_security_group.nlb[0].id
  description                  = "To the engine: ${each.key}"
  referenced_security_group_id = aws_security_group.engine.id
  ip_protocol                  = "tcp"
  from_port                    = each.value
  to_port                      = each.value
  tags                         = var.tags
}

resource "aws_security_group" "alb" {
  count = local.create_alb ? 1 : 0

  name        = "pathways-${var.name}-alb"
  description = "Pathways ${var.name}: the application load balancer for the HTTP sources"
  vpc_id      = var.vpc_id
  tags        = var.tags
}

resource "aws_vpc_security_group_ingress_rule" "alb" {
  for_each = local.alb_ingress

  security_group_id = aws_security_group.alb[0].id
  description       = "HTTP source ${each.key}"
  cidr_ipv4         = each.value.cidr
  ip_protocol       = "tcp"
  from_port         = each.value.port
  to_port           = each.value.port
  tags              = var.tags
}

resource "aws_vpc_security_group_egress_rule" "alb_to_engine" {
  for_each = local.alb_to_engine

  security_group_id            = aws_security_group.alb[0].id
  description                  = "To the engine: ${each.key}"
  referenced_security_group_id = aws_security_group.engine.id
  ip_protocol                  = "tcp"
  from_port                    = each.value
  to_port                      = each.value
  tags                         = var.tags
}
