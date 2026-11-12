variable "name" {
  description = "Name of the deployment. It prefixes the load balancer and target group names, which AWS caps at 32 characters."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,22}[a-z0-9]$", var.name))
    error_message = "name must be 2 to 24 characters of lowercase letters, digits and hyphens, start with a letter and not end with a hyphen: it prefixes the load balancer and target group names, which AWS caps at 32 characters."
  }
}

variable "vpc_id" {
  description = "The VPC of the target groups."
  type        = string
}

variable "subnet_ids" {
  description = "Subnets for the load balancers, in at least two availability zones. An internet-facing load balancer (internal = false) needs public subnets here."
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "subnet_ids needs at least two subnets, in two availability zones."
  }
}

variable "internal" {
  description = "Whether the load balancers are internal, reachable only from inside the VPC and what is connected to it. The default; set false only with public subnets and narrow security groups."
  type        = bool
  default     = true
}

variable "mllp_sources" {
  description = "The MLLP sources, by name, each with the port it listens on. Each gets a TCP listener on the network load balancer, on the same port, passed through to the engine, which terminates its own TLS. Empty creates no network load balancer."
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
  description = "The HTTP sources, by name, each with the port it listens on. Each gets an HTTPS listener on the application load balancer, on the same port, forwarding to the engine with http_target_protocol. Empty creates no application load balancer."
  type = map(object({
    port = number
  }))
  default = {}

  validation {
    condition     = alltrue([for s in values(var.http_sources) : s.port >= 1 && s.port <= 65535 && floor(s.port) == s.port])
    error_message = "Each HTTP source needs a whole port from 1 to 65535."
  }
}

variable "nlb_security_group_id" {
  description = "ID of the network load balancer's security group. Needed when mllp_sources is not empty."
  type        = string
  default     = null

  validation {
    condition     = length(var.mllp_sources) == 0 || var.nlb_security_group_id != null
    error_message = "mllp_sources needs nlb_security_group_id."
  }
}

variable "alb_security_group_id" {
  description = "ID of the application load balancer's security group. Needed when http_sources is not empty."
  type        = string
  default     = null

  validation {
    condition     = length(var.http_sources) == 0 || var.alb_security_group_id != null
    error_message = "http_sources needs alb_security_group_id."
  }
}

variable "http_target_protocol" {
  description = "How the application load balancer reaches the engine's HTTP sources: HTTPS, to an HTTP source with its own tls block (the default), or HTTP, to one with plaintext: true."
  type        = string
  default     = "HTTPS"

  validation {
    condition     = contains(["HTTPS", "HTTP"], var.http_target_protocol)
    error_message = "http_target_protocol must be HTTPS or HTTP."
  }
}

variable "alb_certificate_arn" {
  description = "ARN of the ACM certificate the application load balancer's HTTPS listeners present. Needed when http_sources is not empty."
  type        = string
  default     = null

  validation {
    condition     = length(var.http_sources) == 0 || var.alb_certificate_arn != null
    error_message = "http_sources needs alb_certificate_arn: the application load balancer's listeners are HTTPS only."
  }
}

variable "alb_ssl_policy" {
  description = "The TLS policy of the application load balancer's HTTPS listeners."
  type        = string
  default     = "ELBSecurityPolicy-TLS13-1-2-2021-06"
}

variable "probe_port" {
  description = "The port of the engine's probe listener. The target groups check /readyz on it."
  type        = number
  default     = 9091

  validation {
    condition     = var.probe_port >= 1 && var.probe_port <= 65535 && floor(var.probe_port) == var.probe_port
    error_message = "probe_port must be a whole port from 1 to 65535."
  }
}

variable "drain_timeout_seconds" {
  description = "The target groups' deregistration delay: how long they wait for a stopping engine's open connections before closing them."
  type        = number
  default     = 60

  validation {
    condition     = var.drain_timeout_seconds >= 0 && var.drain_timeout_seconds <= 3600 && floor(var.drain_timeout_seconds) == var.drain_timeout_seconds
    error_message = "drain_timeout_seconds must be a whole number from 0 to 3600."
  }
}

variable "deletion_protection" {
  description = "Whether the load balancers refuse deletion. Turn it off, and apply, before you destroy the module."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags added to every resource the module creates. The caller's provider default_tags apply as well."
  type        = map(string)
  default     = {}
}
