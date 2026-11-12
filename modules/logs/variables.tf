variable "log_group_prefix" {
  description = "The prefix of both log groups: <prefix>/engine and <prefix>/migrate. The key's policy must let CloudWatch Logs use it under this prefix."
  type        = string

  validation {
    condition     = can(regex("^/[A-Za-z0-9_./#-]*[A-Za-z0-9_.#-]$", var.log_group_prefix))
    error_message = "log_group_prefix must start with a slash, not end with one, and hold only the characters a log group name allows."
  }
}

variable "kms_key_arn" {
  description = "ARN of the customer managed KMS key that encrypts both log groups."
  type        = string
}

variable "retention_days" {
  description = "How many days CloudWatch Logs keeps the engine's and the migrate task's logs. They hold ids, counts and codes, never message content."
  type        = number
  default     = 365

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.retention_days)
    error_message = "retention_days must be a retention CloudWatch Logs offers, such as 30, 90, 365 or 731."
  }
}

variable "tags" {
  description = "Tags added to both log groups. The caller's provider default_tags apply as well."
  type        = map(string)
  default     = {}
}
