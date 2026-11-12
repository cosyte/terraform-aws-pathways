variable "name" {
  description = "Name of the deployment. The cluster is pathways-<name>, and the task definitions and the service are named from it."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,22}[a-z0-9]$", var.name))
    error_message = "name must be 2 to 24 characters of lowercase letters, digits and hyphens, start with a letter and not end with a hyphen."
  }
}

variable "image" {
  description = "The engine's image, named by digest: registry/repository:tag@sha256:<64 hex digits>, or registry/repository@sha256:<digest>. A tag alone is refused."
  type        = string

  validation {
    condition     = can(regex("^[^@[:space:]]+@sha256:[0-9a-f]{64}$", var.image))
    error_message = "image must name the image by digest, ending in @sha256: and 64 lowercase hex digits."
  }
}

variable "migrate_image" {
  description = "The image the migrate task definition runs, by digest. Null runs image."
  type        = string
  default     = null

  validation {
    condition     = var.migrate_image == null || can(regex("^[^@[:space:]]+@sha256:[0-9a-f]{64}$", var.migrate_image))
    error_message = "migrate_image must name the image by digest, ending in @sha256: and 64 lowercase hex digits, or be null."
  }
}

variable "repository_credentials_secret_arn" {
  description = "ARN of a Secrets Manager secret holding a username and password for a private registry other than ECR. Null for ECR or a public image."
  type        = string
  default     = null
}

variable "cpu" {
  description = "CPU units for each task, 1024 to a vCPU."
  type        = number
  default     = 1024

  validation {
    condition     = contains([256, 512, 1024, 2048, 4096, 8192, 16384], var.cpu)
    error_message = "cpu must be a Fargate task size: 256, 512, 1024, 2048, 4096, 8192 or 16384."
  }
}

variable "memory" {
  description = "Memory for each task, in MiB. It must be a size Fargate allows for the cpu chosen; AWS refuses the task definition otherwise."
  type        = number
  default     = 2048

  validation {
    condition     = var.memory >= 512 && var.memory <= 122880 && floor(var.memory) == var.memory
    error_message = "memory must be a whole number of MiB from 512 to 122880."
  }
}

variable "cpu_architecture" {
  description = "The CPU architecture of the tasks: X86_64 or ARM64. The image must be built for the one chosen."
  type        = string
  default     = "X86_64"

  validation {
    condition     = contains(["X86_64", "ARM64"], var.cpu_architecture)
    error_message = "cpu_architecture must be X86_64 or ARM64."
  }
}

variable "container_ports" {
  description = "Every port the engine container listens on: each source's, and the probe listener's."
  type        = list(number)

  validation {
    condition     = length(distinct(var.container_ports)) == length(var.container_ports) && alltrue([for p in var.container_ports : p >= 1 && p <= 65535 && floor(p) == p])
    error_message = "container_ports must be distinct whole ports from 1 to 65535."
  }
}

variable "environment" {
  description = "Plain settings for the engine, as environment variables. Never a secret: those go in secrets."
  type        = map(string)
  default     = {}

  validation {
    condition     = alltrue([for k in keys(var.environment) : can(regex("^[A-Za-z_][A-Za-z0-9_]*$", k))])
    error_message = "Each environment variable name must be letters, digits and underscores, not starting with a digit."
  }
}

variable "secrets" {
  description = "Secrets for the engine, as environment variables, each the ARN of a Secrets Manager secret (optionally with :json-key:: and a version suffix) or of an SSM parameter, which ECS reads when the task starts. The execution role must be allowed to read each."
  type        = map(string)
  default     = {}

  validation {
    condition     = alltrue([for k in keys(var.secrets) : can(regex("^[A-Za-z_][A-Za-z0-9_]*$", k))])
    error_message = "Each secret's variable name must be letters, digits and underscores, not starting with a digit."
  }

  validation {
    condition     = alltrue([for v in values(var.secrets) : can(regex("^arn:aws[a-z-]*:(secretsmanager|ssm):", v))])
    error_message = "Each secret must be the ARN of a Secrets Manager secret or an SSM parameter."
  }

  validation {
    condition     = length(setintersection(keys(var.secrets), keys(var.environment))) == 0
    error_message = "A variable name may be in environment or in secrets, not both."
  }
}

variable "execution_role_arn" {
  description = "ARN of the role ECS starts the tasks with: it pulls the image, reads the secrets and writes the logs."
  type        = string
}

variable "task_role_arn" {
  description = "ARN of the role the tasks run as."
  type        = string
}

variable "engine_log_group_name" {
  description = "Name of the CloudWatch log group the engine's awslogs driver writes to."
  type        = string
}

variable "migrate_log_group_name" {
  description = "Name of the CloudWatch log group the migrate task's awslogs driver writes to."
  type        = string
}

variable "drain_timeout_seconds" {
  description = "The engine container's stop timeout, the time between SIGTERM and SIGKILL. Fargate allows at most 120 seconds."
  type        = number
  default     = 60

  validation {
    condition     = var.drain_timeout_seconds >= 2 && var.drain_timeout_seconds <= 120 && floor(var.drain_timeout_seconds) == var.drain_timeout_seconds
    error_message = "drain_timeout_seconds must be a whole number from 2 to 120: Fargate's stop timeout is at most 120 seconds."
  }
}

variable "health_check_grace_period_seconds" {
  description = "How long ECS waits after a task starts before it acts on the load balancers' health checks. Unused when load_balancers is empty."
  type        = number
  default     = 120

  validation {
    condition     = var.health_check_grace_period_seconds >= 0 && var.health_check_grace_period_seconds <= 3600
    error_message = "health_check_grace_period_seconds must be from 0 to 3600."
  }
}

variable "container_insights" {
  description = "Whether the cluster runs Container Insights. It writes performance metrics only, never message content, to a log group AWS creates, which is not encrypted under your key and is billed by CloudWatch. Off by default."
  type        = bool
  default     = false
}

variable "subnet_ids" {
  description = "Private subnets for the engine's tasks. The tasks get no public IP address."
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) > 0
    error_message = "subnet_ids needs at least one subnet."
  }
}

variable "security_group_ids" {
  description = "The security groups of the engine's tasks."
  type        = list(string)

  validation {
    condition     = length(var.security_group_ids) > 0
    error_message = "security_group_ids needs at least one security group: without one the VPC's default group applies."
  }
}

variable "load_balancers" {
  description = "The target groups the service registers the engine with, by any key, each with the container port it forwards to. Empty runs the service with no load balancer."
  type = map(object({
    target_group_arn = string
    container_port   = number
  }))
  default = {}

  validation {
    condition     = length(var.load_balancers) <= 5
    error_message = "An ECS service attaches to at most five target groups."
  }

  validation {
    condition     = alltrue([for lb in values(var.load_balancers) : contains(var.container_ports, lb.container_port)])
    error_message = "Each load balancer's container_port must be one of container_ports."
  }
}

variable "tags" {
  description = "Tags added to every resource the module creates. The caller's provider default_tags apply as well."
  type        = map(string)
  default     = {}
}
