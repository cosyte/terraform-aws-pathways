variable "name" {
  description = "Name of the deployment. The groups are pathways-<name>-engine, -database, -nlb and -alb."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,22}[a-z0-9]$", var.name))
    error_message = "name must be 2 to 24 characters of lowercase letters, digits and hyphens, start with a letter and not end with a hyphen."
  }
}

variable "vpc_id" {
  description = "The VPC the security groups belong to."
  type        = string
}

variable "allowed_cidr_blocks" {
  description = "The networks allowed to connect to the MLLP and HTTP sources through the load balancers. There is no default, so nothing is open until you say what is."
  type        = list(string)

  validation {
    condition     = length(var.allowed_cidr_blocks) > 0 && alltrue([for c in var.allowed_cidr_blocks : can(cidrnetmask(c))])
    error_message = "allowed_cidr_blocks needs at least one IPv4 CIDR block, such as 10.20.0.0/16."
  }
}

variable "mllp_sources" {
  description = "The MLLP sources, by name, each with the port it listens on. Empty creates no network load balancer group."
  type = map(object({
    port = number
  }))
  default = {}

  validation {
    condition     = alltrue([for s in values(var.mllp_sources) : s.port >= 1 && s.port <= 65535 && floor(s.port) == s.port])
    error_message = "Each MLLP source needs a whole port from 1 to 65535."
  }
}

variable "http_sources" {
  description = "The HTTP sources, by name, each with the port it listens on. Empty creates no application load balancer group."
  type = map(object({
    port = number
  }))
  default = {}

  validation {
    condition     = alltrue([for s in values(var.http_sources) : s.port >= 1 && s.port <= 65535 && floor(s.port) == s.port])
    error_message = "Each HTTP source needs a whole port from 1 to 65535."
  }
}

variable "probe_port" {
  description = "The port of the engine's probe listener, which each load balancer may reach for its health checks."
  type        = number
  default     = 9091

  validation {
    condition     = var.probe_port >= 1 && var.probe_port <= 65535 && floor(var.probe_port) == var.probe_port
    error_message = "probe_port must be a whole port from 1 to 65535."
  }
}

variable "egress_rules" {
  description = "Where the engine may connect, other than the database, which is always allowed: each rule is a TCP port and the networks it may reach. The default allows HTTPS anywhere, which the tasks need for the image registry, Secrets Manager and CloudWatch Logs through a NAT gateway; with VPC endpoints for those, narrow it."
  type = map(object({
    port        = number
    cidr_blocks = list(string)
  }))
  default = {
    https = {
      port        = 443
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  validation {
    condition     = alltrue([for r in values(var.egress_rules) : r.port >= 1 && r.port <= 65535 && floor(r.port) == r.port && length(r.cidr_blocks) > 0])
    error_message = "Each egress rule needs a whole port from 1 to 65535 and at least one CIDR block."
  }
}

variable "database_security_group_id" {
  description = "The security group of an existing database the engine uses. Null creates the database's own group. Given, the module creates none, lets the engine reach that group on 5432, and adds a rule to it that admits the engine on 5432."
  type        = string
  default     = null

  validation {
    condition     = var.database_security_group_id == null || can(regex("^sg-[0-9a-f]{8,17}$", var.database_security_group_id))
    error_message = "database_security_group_id must be a security group id, such as sg-0a1b2c3d4e5f60718, or null."
  }
}

variable "tags" {
  description = "Tags added to every group and rule. The caller's provider default_tags apply as well."
  type        = map(string)
  default     = {}
}
