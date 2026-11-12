variable "name" {
  description = "Name of the deployment. The roles are pathways-<name>-execution and pathways-<name>-task."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,22}[a-z0-9]$", var.name))
    error_message = "name must be 2 to 24 characters of lowercase letters, digits and hyphens, start with a letter and not end with a hyphen."
  }
}

variable "images" {
  description = "The images the tasks run, by digest. Each one in ECR lets the execution role pull from its own repository, and no other; an image outside ECR gives no ECR permission. Null entries are skipped."
  type        = list(string)
}

variable "secrets" {
  description = "The secrets ECS injects into the tasks, by variable name, each the ARN of a Secrets Manager secret (optionally with :json-key:: and a version suffix) or of an SSM parameter. The execution role may read exactly these."
  type        = map(string)
  default     = {}

  validation {
    condition     = alltrue([for v in values(var.secrets) : can(regex("^arn:aws[a-z-]*:(secretsmanager|ssm):", v))])
    error_message = "Each secret must be the ARN of a Secrets Manager secret or an SSM parameter."
  }
}

variable "repository_credentials_secret_arn" {
  description = "ARN of a Secrets Manager secret holding a username and password for a private registry other than ECR, which the execution role may read. Null for ECR or a public image."
  type        = string
  default     = null
}

variable "kms_key_arns" {
  description = "ARNs of the customer managed KMS keys that encrypt the secrets, which the execution role may decrypt with."
  type        = list(string)
  default     = []
}

variable "log_group_arns" {
  description = "ARNs of the CloudWatch log groups the tasks' awslogs driver writes to."
  type        = list(string)

  validation {
    condition     = length(var.log_group_arns) > 0
    error_message = "log_group_arns needs at least one log group: the tasks log through the awslogs driver."
  }
}

variable "tags" {
  description = "Tags added to both roles. The caller's provider default_tags apply as well."
  type        = map(string)
  default     = {}
}
