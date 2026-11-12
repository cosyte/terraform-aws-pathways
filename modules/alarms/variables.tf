variable "name" {
  description = "Name of the deployment. The alarms are pathways-<name>-<alarm>, the token's secret pathways/<name>/health-token, and each metric carries the dimension Deployment = <name>."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,22}[a-z0-9]$", var.name))
    error_message = "name must be 2 to 24 characters of lowercase letters, digits and hyphens, start with a letter and not end with a hyphen."
  }
}

variable "log_group_prefix" {
  description = "The prefix of the deployment's log groups. The collector writes the metrics, as CloudWatch embedded metric format lines, to <prefix>/metrics. The key's policy must let CloudWatch Logs use it under this prefix."
  type        = string

  validation {
    condition     = can(regex("^/[A-Za-z0-9_./#-]*[A-Za-z0-9_.#-]$", var.log_group_prefix))
    error_message = "log_group_prefix must start with a slash, not end with one, and hold only the characters a log group name allows."
  }
}

variable "kms_key_arn" {
  description = "ARN of the customer managed KMS key that encrypts the metrics log group and the health token's secret. Its key policy must let IAM policies in the account grant its use, as the kms submodule's does."
  type        = string
}

variable "log_retention_days" {
  description = "How many days CloudWatch Logs keeps the metrics log group's lines. They hold the four metrics the alarms read, with no channel or destination name."
  type        = number
  default     = 365

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.log_retention_days)
    error_message = "log_retention_days must be a retention CloudWatch Logs offers, such as 30, 90, 365 or 731."
  }
}

variable "task_role_name" {
  description = "Name of the role the engine's task runs as. The collector runs as it too, so it gets logs:CreateLogStream and logs:PutLogEvents on the metrics log group, and nothing else."
  type        = string
}

variable "sns_topic_arn" {
  description = "ARN of the SNS topic each alarm publishes to when it goes into alarm and when it comes back to OK. You create the topic and its subscriptions; if it is encrypted, its key must let CloudWatch use it."
  type        = string

  validation {
    condition     = can(regex("^arn:aws[a-z-]*:sns:[a-z0-9-]+:[0-9]{12}:[A-Za-z0-9_-]+(\\.fifo)?$", var.sns_topic_arn))
    error_message = "sns_topic_arn must be the ARN of an SNS topic, such as arn:aws:sns:us-east-1:123456789012:pathways-alarms."
  }
}

variable "health_port" {
  description = "The port of the engine's health endpoint, the health block of your pathways.yaml, which serves /metrics. The collector reads it at 127.0.0.1 inside the task, so the block can keep its default host, 127.0.0.1."
  type        = number
  default     = 9090

  validation {
    condition     = var.health_port >= 1 && var.health_port <= 65535 && floor(var.health_port) == var.health_port
    error_message = "health_port must be a whole port from 1 to 65535."
  }
}

variable "health_token_version" {
  description = "Raise this by one to write a new health token: the module generates one and writes it to its secret, and neither the plan nor the state ever holds it. The engine and the collector read it when a task starts, so force a new deployment of the service after you raise it."
  type        = number
  default     = 1

  validation {
    condition     = var.health_token_version >= 1 && floor(var.health_token_version) == var.health_token_version
    error_message = "health_token_version must be a whole number, 1 or more."
  }
}

variable "store_down_minutes" {
  description = "How many minutes in a row pathways_store_up must be below 1, or missing, before the store down alarm fires. Missing counts: an engine or a collector that stopped reporting fires it too."
  type        = number
  default     = 2

  validation {
    condition     = var.store_down_minutes >= 1 && var.store_down_minutes <= 60 && floor(var.store_down_minutes) == var.store_down_minutes
    error_message = "store_down_minutes must be a whole number from 1 to 60."
  }
}

variable "oldest_pending_age_seconds" {
  description = "The oldest pending age alarm fires when the oldest delivery waiting on any destination has waited longer than this, in seconds, for 5 minutes in a row."
  type        = number
  default     = 600

  validation {
    condition     = var.oldest_pending_age_seconds >= 0
    error_message = "oldest_pending_age_seconds must be 0 or more."
  }
}

variable "refused_messages_threshold" {
  description = "The refused messages alarm fires when the bodies the sources refused (unreadable or rejected, all channels together) number more than this in 15 minutes. 0 fires on the first one."
  type        = number
  default     = 0

  validation {
    condition     = var.refused_messages_threshold >= 0 && floor(var.refused_messages_threshold) == var.refused_messages_threshold
    error_message = "refused_messages_threshold must be a whole number, 0 or more."
  }
}

variable "settled_failed_threshold" {
  description = "The settled destinations failing alarm fires when the messages that settled as failed with a destination (all channels and destinations together) number more than this in 15 minutes. 0 fires on the first one."
  type        = number
  default     = 0

  validation {
    condition     = var.settled_failed_threshold >= 0 && floor(var.settled_failed_threshold) == var.settled_failed_threshold
    error_message = "settled_failed_threshold must be a whole number, 0 or more."
  }
}

variable "tags" {
  description = "Tags added to every resource the module creates. The caller's provider default_tags apply as well."
  type        = map(string)
  default     = {}
}
