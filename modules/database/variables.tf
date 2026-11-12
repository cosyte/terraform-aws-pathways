variable "name" {
  description = "Name of the deployment. The instance, its subnet group, its parameter group, its final snapshot and its secret are named from it."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,22}[a-z0-9]$", var.name))
    error_message = "name must be 2 to 24 characters of lowercase letters, digits and hyphens, start with a letter and not end with a hyphen."
  }
}

variable "subnet_ids" {
  description = "Subnets for the database, in at least two availability zones."
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "subnet_ids needs at least two subnets, in two availability zones."
  }
}

variable "security_group_ids" {
  description = "The security groups of the database. Only what they admit reaches it."
  type        = list(string)

  validation {
    condition     = length(var.security_group_ids) > 0
    error_message = "security_group_ids needs at least one security group: without one the VPC's default group applies."
  }
}

variable "kms_key_arn" {
  description = "ARN of the customer managed KMS key that encrypts the connection URL secret, and the storage too unless storage_kms_key_arn is given."
  type        = string
}

variable "storage_kms_key_arn" {
  description = "ARN of a KMS key that encrypts the database's storage, its automated backups and its final snapshot instead of kms_key_arn, so the snapshot can outlive that key. Null uses kms_key_arn. Its key policy must let RDS use it for the role that applies."
  type        = string
  default     = null

  validation {
    condition     = var.storage_kms_key_arn == null || can(regex("^arn:aws[a-z-]*:kms:[a-z0-9-]+:[0-9]{12}:key/[A-Za-z0-9-]+$", var.storage_kms_key_arn))
    error_message = "storage_kms_key_arn must be a KMS key ARN (arn:aws:kms:<region>:<account>:key/<id>), not an alias, or null."
  }
}

variable "engine_version" {
  description = "The PostgreSQL version of the RDS instance, a major version such as 17, or a full one."
  type        = string
  default     = "17"
}

variable "parameter_group_family" {
  description = "The parameter group family matching engine_version, such as postgres17."
  type        = string
  default     = "postgres17"
}

variable "instance_class" {
  description = "The RDS instance class of the database."
  type        = string
  default     = "db.t4g.medium"
}

variable "allocated_storage" {
  description = "The database's starting storage, in GiB."
  type        = number
  default     = 50
}

variable "max_allocated_storage" {
  description = "The most storage, in GiB, RDS may grow the database to on its own. Equal to allocated_storage turns that off."
  type        = number
  default     = 200
}

variable "multi_az" {
  description = "Whether RDS keeps a standby copy of the database in a second availability zone and fails over to it."
  type        = bool
  default     = true
}

variable "backup_retention_days" {
  description = "How many days RDS keeps automated backups of the database."
  type        = number
  default     = 14

  validation {
    condition     = var.backup_retention_days >= 1 && var.backup_retention_days <= 35
    error_message = "backup_retention_days must be from 1 to 35."
  }
}

variable "database_name" {
  description = "The name of the database Pathways stores messages in."
  type        = string
  default     = "pathways"

  validation {
    condition     = can(regex("^[a-z][a-z0-9_]{0,62}$", var.database_name))
    error_message = "database_name must be lowercase letters, digits and underscores, starting with a letter."
  }
}

variable "username" {
  description = "The database's master user, which Pathways connects as."
  type        = string
  default     = "pathways"

  validation {
    condition     = can(regex("^[a-z][a-z0-9_]{0,62}$", var.username))
    error_message = "username must be lowercase letters, digits and underscores, starting with a letter."
  }
}

variable "password_version" {
  description = "Raise this by one to set a new password: the module generates one, sets it on the database and writes the new connection URL to its secret in the same run, and neither the plan nor the state ever holds it."
  type        = number
  default     = 1

  validation {
    condition     = var.password_version >= 1 && floor(var.password_version) == var.password_version
    error_message = "password_version must be a whole number, 1 or more."
  }
}

variable "deletion_protection" {
  description = "Whether the database refuses deletion. Turn it off, and apply, before you destroy the module."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags added to every resource the module creates. The caller's provider default_tags apply as well."
  type        = map(string)
  default     = {}
}
