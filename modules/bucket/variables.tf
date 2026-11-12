variable "name" {
  description = "Name of the deployment. The bucket's name starts pathways-<name>-, the log bucket's <name>-access-logs-, and S3 adds a unique suffix to each."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,22}[a-z0-9]$", var.name))
    error_message = "name must be 2 to 24 characters of lowercase letters, digits and hyphens, start with a letter and not end with a hyphen."
  }
}

variable "kms_key_arn" {
  description = "ARN of the customer managed KMS key the bucket's objects are encrypted under (SSE-KMS, with an S3 Bucket Key). Its key policy must let IAM policies in the account grant its use, as the kms submodule's does."
  type        = string

  validation {
    condition     = can(regex("^arn:aws[a-z-]*:kms:[a-z0-9-]+:[0-9]{12}:key/[A-Za-z0-9-]+$", var.kms_key_arn))
    error_message = "kms_key_arn must be a KMS key ARN (arn:aws:kms:<region>:<account>:key/<id>), not an alias."
  }
}

variable "lifecycle_rules" {
  description = "Lifecycle rules, by id, each for the keys under prefix (\"\" for all): days until a current object expires, days until a replaced or deleted (noncurrent) version is removed, and days until an unfinished multipart upload is aborted. Null leaves that action out. The bucket is versioned, so an object Pathways deletes after reading stays as a noncurrent version until a rule removes it. The default removes noncurrent versions after 30 days and unfinished uploads after 7, and never expires a current object. An empty map sets no rule."
  type = map(object({
    prefix                                 = optional(string, "")
    expiration_days                        = optional(number)
    noncurrent_version_expiration_days     = optional(number)
    abort_incomplete_multipart_upload_days = optional(number)
  }))
  default = {
    default = {
      noncurrent_version_expiration_days     = 30
      abort_incomplete_multipart_upload_days = 7
    }
  }

  validation {
    condition = alltrue(flatten([
      for r in values(var.lifecycle_rules) : [
        for d in [r.expiration_days, r.noncurrent_version_expiration_days, r.abort_incomplete_multipart_upload_days] :
        d == null ? true : d >= 1 && floor(d) == d
      ]
    ]))
    error_message = "Each lifecycle rule's days must be a whole number, 1 or more, or null."
  }

  validation {
    condition = alltrue([
      for r in values(var.lifecycle_rules) :
      r.expiration_days != null || r.noncurrent_version_expiration_days != null || r.abort_incomplete_multipart_upload_days != null
    ])
    error_message = "Each lifecycle rule needs at least one action: expiration_days, noncurrent_version_expiration_days or abort_incomplete_multipart_upload_days."
  }

  validation {
    condition     = alltrue([for k in keys(var.lifecycle_rules) : can(regex("^[A-Za-z0-9_.-]{1,255}$", k))])
    error_message = "Each lifecycle rule's id must be 1 to 255 letters, digits, dots, hyphens and underscores."
  }
}

variable "access_log_retention_days" {
  description = "How many days the log bucket keeps the bucket's server access logs. They name each object's key and who asked for it, never an object's content; a key a sender chooses can still carry what a file name carries."
  type        = number
  default     = 365

  validation {
    condition     = var.access_log_retention_days >= 1 && floor(var.access_log_retention_days) == var.access_log_retention_days
    error_message = "access_log_retention_days must be a whole number, 1 or more."
  }
}

variable "task_role_name" {
  description = "Name of the role the Pathways tasks run as, which gets an inline policy to list the bucket, read, write and delete its objects, and use the key for them. Null attaches nothing."
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags added to both buckets. The caller's provider default_tags apply as well."
  type        = map(string)
  default     = {}
}
