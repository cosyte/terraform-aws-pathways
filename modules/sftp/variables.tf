variable "name" {
  description = "Name of the deployment. The security group is pathways-<name>-sftp, and the roles start pathways-<name>-sftp-."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,22}[a-z0-9]$", var.name))
    error_message = "name must be 2 to 24 characters of lowercase letters, digits and hyphens, start with a letter and not end with a hyphen."
  }
}

variable "vpc_id" {
  description = "The VPC the SFTP endpoint is in."
  type        = string
}

variable "subnet_ids" {
  description = "Subnets for the SFTP endpoint, one network interface in each. Private subnets keep it internal: the module gives it no Elastic IP."
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) > 0
    error_message = "subnet_ids needs at least one subnet."
  }
}

variable "allowed_cidr_blocks" {
  description = "The networks allowed to connect to the SFTP endpoint, on port 22: your partners' addresses, or your VPN's. There is no default, and 0.0.0.0/0 is refused, so nothing is open until you name who may connect."
  type        = list(string)

  validation {
    condition     = length(var.allowed_cidr_blocks) > 0 && alltrue([for c in var.allowed_cidr_blocks : can(cidrnetmask(c))])
    error_message = "allowed_cidr_blocks needs at least one IPv4 CIDR block, such as 10.20.0.0/16."
  }

  validation {
    condition     = alltrue([for c in var.allowed_cidr_blocks : !can(cidrnetmask(c)) || try(tonumber(split("/", c)[1]) > 0, false)])
    error_message = "allowed_cidr_blocks may not hold 0.0.0.0/0, or any /0 block: name the networks that may connect."
  }
}

variable "bucket_name" {
  description = "Name of the S3 bucket the users' home prefixes are in, such as the bucket submodule's bucket_name."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.bucket_name))
    error_message = "bucket_name must be an S3 bucket name."
  }
}

variable "kms_key_arn" {
  description = "ARN of the customer managed KMS key that encrypts the log group and the bucket's objects. The users' roles may use it through S3 alone, and the key's policy must let CloudWatch Logs use it for log_group_name."
  type        = string

  validation {
    condition     = can(regex("^arn:aws[a-z-]*:kms:[a-z0-9-]+:[0-9]{12}:key/[A-Za-z0-9-]+$", var.kms_key_arn))
    error_message = "kms_key_arn must be a KMS key ARN (arn:aws:kms:<region>:<account>:key/<id>), not an alias."
  }
}

variable "users" {
  description = "The SFTP users, by user name, each with its SSH public keys (one OpenSSH public key per entry: ssh-ed25519, ecdsa-sha2-nistp256, -384 or -521, or ssh-rsa) and the prefix in the bucket that is its home, such as partners/lab. A user sees its prefix as / and reaches nothing outside it. Users are service managed: no password, keys only."
  type = map(object({
    public_keys = list(string)
    home_prefix = string
  }))
  default = {}

  validation {
    condition     = alltrue([for u in keys(var.users) : can(regex("^[A-Za-z0-9_][A-Za-z0-9_@.-]{2,99}$", u))])
    error_message = "Each user name must be 3 to 100 letters, digits, underscores, hyphens, periods and at signs, not starting with a hyphen, period or at sign."
  }

  validation {
    condition     = alltrue([for u in values(var.users) : length(u.public_keys) > 0])
    error_message = "Each user needs at least one SSH public key: users sign in with a key, never a password."
  }

  validation {
    condition = alltrue(flatten([
      for u in values(var.users) : [
        for k in u.public_keys : can(regex("^(ssh-ed25519|ssh-rsa|ecdsa-sha2-nistp256|ecdsa-sha2-nistp384|ecdsa-sha2-nistp521) [A-Za-z0-9+/]+={0,2}( [^\\n]*)?$", k))
      ]
    ]))
    error_message = "Each public key must be one OpenSSH public key line: ssh-ed25519, ecdsa-sha2-nistp256, -384 or -521, or ssh-rsa, then the key in base64, then an optional comment. Never a private key."
  }

  # The prefix goes unchanged into the user's role policy, as an object ARN and an s3:prefix
  # StringLike value, where * and ? are wildcards: neither is allowed.
  validation {
    condition = alltrue([
      for u in values(var.users) :
      can(regex("^[A-Za-z0-9!_.'()-]+(/[A-Za-z0-9!_.'()-]+)*$", u.home_prefix))
      && !contains(split("/", u.home_prefix), ".")
      && !contains(split("/", u.home_prefix), "..")
    ])
    error_message = "Each home_prefix must be a key prefix such as partners/lab: segments of letters, digits and !_.'()- joined by single slashes, with no leading or trailing slash, no . or .. segment and no * or ?, which the user's role policy would read as wildcards."
  }
}

variable "security_policy_name" {
  description = "The Transfer Family security policy, which sets the SSH ciphers, key exchanges and MACs the server offers."
  type        = string
  default     = "TransferSecurityPolicy-2024-01"

  validation {
    condition     = can(regex("^TransferSecurityPolicy-", var.security_policy_name))
    error_message = "security_policy_name must name a Transfer Family security policy, such as TransferSecurityPolicy-2024-01."
  }
}

variable "log_group_name" {
  description = "Name of the CloudWatch log group the server writes its structured logs to. The key's policy must let CloudWatch Logs use the key for it."
  type        = string

  validation {
    condition     = can(regex("^/[A-Za-z0-9_./#-]*[A-Za-z0-9_.#-]$", var.log_group_name))
    error_message = "log_group_name must start with a slash, not end with one, and hold only the characters a log group name allows."
  }
}

variable "log_retention_days" {
  description = "How many days CloudWatch Logs keeps the server's logs. They name users, files and addresses, never a file's content."
  type        = number
  default     = 365

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.log_retention_days)
    error_message = "log_retention_days must be a retention CloudWatch Logs offers, such as 30, 90, 365 or 731."
  }
}

variable "tags" {
  description = "Tags added to every resource the submodule creates. The caller's provider default_tags apply as well."
  type        = map(string)
  default     = {}
}
