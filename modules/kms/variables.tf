variable "name" {
  description = "Name of the deployment. The key's description and its alias, alias/pathways-<name>, are made from it."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,22}[a-z0-9]$", var.name))
    error_message = "name must be 2 to 24 characters of lowercase letters, digits and hyphens, start with a letter and not end with a hyphen."
  }
}

variable "log_group_prefix" {
  description = "The prefix of the log groups CloudWatch Logs may encrypt with the key, such as /pathways/<name>. Log groups outside it cannot use the key."
  type        = string

  validation {
    condition     = can(regex("^/[A-Za-z0-9_./#-]*[A-Za-z0-9_.#-]$", var.log_group_prefix))
    error_message = "log_group_prefix must start with a slash, not end with one, and hold only the characters a log group name allows."
  }
}

variable "deletion_window_days" {
  description = "Days between scheduling the key for deletion and its deletion, 7 to 30 (AWS allows no more). Everything it encrypts is unreadable after that."
  type        = number
  default     = 30

  validation {
    condition     = var.deletion_window_days >= 7 && var.deletion_window_days <= 30
    error_message = "deletion_window_days must be from 7 to 30."
  }
}

variable "tags" {
  description = "Tags added to the key. The caller's provider default_tags apply as well."
  type        = map(string)
  default     = {}
}
