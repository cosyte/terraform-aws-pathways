# ---------------------------------------------------------------------------
# Naming and placement
# ---------------------------------------------------------------------------

variable "name" {
  description = "Name of this deployment. Every resource the module creates is named from it, so two deployments in one account and region need two names."
  type        = string
  default     = "pathways"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,22}[a-z0-9]$", var.name))
    error_message = "name must be 2 to 24 characters of lowercase letters, digits and hyphens, start with a letter and not end with a hyphen: it prefixes the load balancer and target group names, which AWS caps at 32 characters."
  }
}

variable "tags" {
  description = "Tags added to every resource the module creates. The caller's provider default_tags apply as well."
  type        = map(string)
  default     = {}
}

variable "vpc_id" {
  description = "The VPC the engine, its database and its load balancers run in."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnets for the engine's tasks, in at least two availability zones. The tasks get no public IP address."
  type        = list(string)

  validation {
    condition     = length(var.private_subnet_ids) >= 2
    error_message = "private_subnet_ids needs at least two subnets, in two availability zones."
  }
}

variable "database_subnet_ids" {
  description = "Subnets for the database, in at least two availability zones. Null uses private_subnet_ids."
  type        = list(string)
  default     = null

  validation {
    condition     = var.database_subnet_ids == null || try(length(var.database_subnet_ids) >= 2, false)
    error_message = "database_subnet_ids needs at least two subnets, in two availability zones, or null."
  }
}

variable "load_balancer_subnet_ids" {
  description = "Subnets for the load balancers. Null uses private_subnet_ids. An internet-facing load balancer (load_balancer_internal = false) needs public subnets here."
  type        = list(string)
  default     = null

  validation {
    condition     = var.load_balancer_subnet_ids == null || try(length(var.load_balancer_subnet_ids) >= 2, false)
    error_message = "load_balancer_subnet_ids needs at least two subnets, in two availability zones, or null."
  }
}

variable "load_balancer_internal" {
  description = "Whether the load balancers are internal, reachable only from inside the VPC and what is connected to it. The default; set false only with public subnets and a narrow allowed_cidr_blocks."
  type        = bool
  default     = true
}

variable "allowed_cidr_blocks" {
  description = "The networks allowed to connect to the MLLP and HTTP sources through the load balancers: your senders' addresses, or your VPN's. There is no default, so nothing is open until you say what is."
  type        = list(string)

  validation {
    condition     = length(var.allowed_cidr_blocks) > 0 && alltrue([for c in var.allowed_cidr_blocks : can(cidrnetmask(c))])
    error_message = "allowed_cidr_blocks needs at least one IPv4 CIDR block, such as 10.20.0.0/16."
  }
}

variable "egress_rules" {
  description = "Where the engine's tasks may connect, other than the database, which is always allowed: each rule is a TCP port and the networks it may reach. The default allows HTTPS anywhere, which the tasks need for the image registry, Secrets Manager and CloudWatch Logs through a NAT gateway; with VPC endpoints for those, narrow it. Add a rule for each destination's port."
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

# ---------------------------------------------------------------------------
# The engine
# ---------------------------------------------------------------------------

variable "image" {
  description = "Your project's own image, built on the Pathways image with your channels inside it, named by digest: registry/repository:tag@sha256:<64 hex digits>, or registry/repository@sha256:<digest>. A tag alone is refused, so a deploy always runs exactly the image you tested."
  type        = string

  validation {
    condition     = can(regex("^[^@[:space:]]+@sha256:[0-9a-f]{64}$", var.image))
    error_message = "image must name the image by digest, ending in @sha256: and 64 lowercase hex digits. Look the digest up with: docker buildx imagetools inspect <image>:<tag>."
  }
}

variable "migrate_image" {
  description = "The image the migrate task definition runs, by digest. Null runs image. A deploy that moves the schema sets it to the new image first, runs the migrate task, then moves image: see the README's Deploy section."
  type        = string
  default     = null

  validation {
    condition     = var.migrate_image == null || can(regex("^[^@[:space:]]+@sha256:[0-9a-f]{64}$", var.migrate_image))
    error_message = "migrate_image must name the image by digest, ending in @sha256: and 64 lowercase hex digits, or be null."
  }
}

variable "repository_credentials_secret_arn" {
  description = "ARN of a Secrets Manager secret holding a username and password for a private registry other than ECR. Null for ECR, which the execution role reads, or a public image."
  type        = string
  default     = null
}

variable "cpu" {
  description = "CPU units for each engine task, 1024 to a vCPU. Raise it, with memory, to scale the engine up: one engine runs per database."
  type        = number
  default     = 1024

  validation {
    condition     = contains([256, 512, 1024, 2048, 4096, 8192, 16384], var.cpu)
    error_message = "cpu must be a Fargate task size: 256, 512, 1024, 2048, 4096, 8192 or 16384."
  }
}

variable "memory" {
  description = "Memory for each engine task, in MiB. It must be a size Fargate allows for the cpu chosen; AWS refuses the task definition otherwise."
  type        = number
  default     = 2048

  validation {
    condition     = var.memory >= 512 && var.memory <= 122880 && floor(var.memory) == var.memory
    error_message = "memory must be a whole number of MiB from 512 to 122880."
  }
}

variable "cpu_architecture" {
  description = "The CPU architecture of the tasks: X86_64 or ARM64. The Pathways image is published for both; your project's image must be built for the one chosen."
  type        = string
  default     = "X86_64"

  validation {
    condition     = contains(["X86_64", "ARM64"], var.cpu_architecture)
    error_message = "cpu_architecture must be X86_64 or ARM64."
  }
}

variable "mllp_sources" {
  description = "The MLLP sources of your pathways.yaml, by name, each with the port it listens on. Each gets a TCP listener on the network load balancer, on the same port, passed through to the engine, which terminates its own TLS. Empty creates no network load balancer."
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
  description = "The HTTP sources of your pathways.yaml, by name, each with the port it listens on. Each gets an HTTPS listener on the application load balancer, on the same port, forwarding to the engine with http_target_protocol. Empty creates no application load balancer."
  type = map(object({
    port = number
  }))
  default = {}

  validation {
    condition     = alltrue([for s in values(var.http_sources) : s.port >= 1 && s.port <= 65535 && floor(s.port) == s.port])
    error_message = "Each HTTP source needs a whole port from 1 to 65535."
  }

  validation {
    condition     = length(var.mllp_sources) + length(var.http_sources) <= 5
    error_message = "An ECS service attaches to at most five target groups, one per source: mllp_sources and http_sources together may name at most five."
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
  description = "The port of the probe listener, the probes block of your pathways.yaml. The load balancers check /readyz on it, and the container health check runs pathways probe, which asks /livez. The block must set host: 0.0.0.0 so the load balancers reach it."
  type        = number
  default     = 9091

  validation {
    condition     = var.probe_port >= 1 && var.probe_port <= 65535 && floor(var.probe_port) == var.probe_port
    error_message = "probe_port must be a whole port from 1 to 65535."
  }

  validation {
    condition     = length(distinct(concat([for s in values(var.mllp_sources) : s.port], [for s in values(var.http_sources) : s.port], [var.probe_port]))) == length(var.mllp_sources) + length(var.http_sources) + 1
    error_message = "Each MLLP source, each HTTP source and the probe listener need a port of their own."
  }
}

variable "drain_timeout_seconds" {
  description = "How long a stopping engine has to drain: the load balancers' deregistration delay, and then the container's stop timeout, the time between SIGTERM and SIGKILL. Fargate allows a stop timeout of at most 120 seconds."
  type        = number
  default     = 60

  validation {
    condition     = var.drain_timeout_seconds >= 2 && var.drain_timeout_seconds <= 120 && floor(var.drain_timeout_seconds) == var.drain_timeout_seconds
    error_message = "drain_timeout_seconds must be a whole number from 2 to 120: Fargate's stop timeout is at most 120 seconds."
  }
}

variable "health_check_grace_period_seconds" {
  description = "How long ECS waits after a task starts before it acts on the load balancers' health checks: long enough for the engine to start, take the lease and turn ready."
  type        = number
  default     = 120

  validation {
    condition     = var.health_check_grace_period_seconds >= 0 && var.health_check_grace_period_seconds <= 3600
    error_message = "health_check_grace_period_seconds must be from 0 to 3600."
  }
}

variable "environment" {
  description = "Plain settings for the engine, as environment variables your pathways.yaml reads with { env: NAME }: ports, hosts, durations, the storage kind. Never a secret: those go in secrets."
  type        = map(string)
  default     = {}

  validation {
    condition     = alltrue([for k in keys(var.environment) : can(regex("^[A-Za-z_][A-Za-z0-9_]*$", k))])
    error_message = "Each environment variable name must be letters, digits and underscores, not starting with a digit."
  }

  validation {
    condition     = !contains(keys(var.environment), "PATHWAYS_DATABASE_URL")
    error_message = "PATHWAYS_DATABASE_URL is set by the module from the database it creates: leave it out of environment."
  }

  validation {
    condition     = !var.bucket_enabled || !contains(keys(var.environment), "PATHWAYS_BUCKET")
    error_message = "PATHWAYS_BUCKET is set by the module from the bucket it creates when bucket_enabled is true: leave it out of environment."
  }
}

variable "secrets" {
  description = "Secrets for the engine, as environment variables, each the ARN of a Secrets Manager secret (optionally with :json-key:: and a version suffix) or of an SSM parameter. ECS reads each when the task starts and sets the variable, so pathways.yaml reads it with { env: NAME }. The master key goes here, such as PATHWAYS_KEY_2026_11. The module sets PATHWAYS_DATABASE_URL itself."
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
    condition     = !contains(keys(var.secrets), "PATHWAYS_DATABASE_URL")
    error_message = "PATHWAYS_DATABASE_URL is set by the module from the database it creates: leave it out of secrets."
  }

  validation {
    condition     = !var.bucket_enabled || !contains(keys(var.secrets), "PATHWAYS_BUCKET")
    error_message = "PATHWAYS_BUCKET is set by the module from the bucket it creates when bucket_enabled is true: leave it out of secrets."
  }

  validation {
    condition     = length(setintersection(keys(var.secrets), keys(var.environment))) == 0
    error_message = "A variable name may be in environment or in secrets, not both."
  }
}

variable "secrets_kms_key_arns" {
  description = "ARNs of customer managed KMS keys that encrypt the secrets you pass in secrets, so the task execution role may decrypt them. The module's own key is always included."
  type        = list(string)
  default     = []
}

variable "container_insights" {
  description = "Whether the ECS cluster runs Container Insights. It writes performance metrics only (CPU, memory, network, task counts), never message content, to a log group AWS creates, /aws/ecs/containerinsights/<cluster>/performance, which is not encrypted under the module's key and is billed by CloudWatch. Off by default."
  type        = bool
  default     = false
}

variable "log_retention_days" {
  description = "How many days CloudWatch Logs keeps the engine's and the migrate task's logs. They hold ids, counts and codes, never message content."
  type        = number
  default     = 365

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.log_retention_days)
    error_message = "log_retention_days must be a retention CloudWatch Logs offers, such as 30, 90, 365 or 731."
  }
}

variable "kms_key_deletion_window_days" {
  description = "Days between scheduling the module's KMS key for deletion and its deletion, 7 to 30 (AWS allows no more). Everything it encrypts is unreadable after that, the database's final snapshot included unless database_kms_key_arn names a key of your own."
  type        = number
  default     = 30

  validation {
    condition     = var.kms_key_deletion_window_days >= 7 && var.kms_key_deletion_window_days <= 30
    error_message = "kms_key_deletion_window_days must be from 7 to 30."
  }
}

# ---------------------------------------------------------------------------
# The database
# ---------------------------------------------------------------------------

variable "database_engine_version" {
  description = "The PostgreSQL version of the RDS instance, a major version such as 17, or a full one."
  type        = string
  default     = "17"
}

variable "database_parameter_group_family" {
  description = "The parameter group family matching database_engine_version, such as postgres17."
  type        = string
  default     = "postgres17"
}

variable "database_instance_class" {
  description = "The RDS instance class of the database."
  type        = string
  default     = "db.t4g.medium"
}

variable "database_allocated_storage" {
  description = "The database's starting storage, in GiB."
  type        = number
  default     = 50
}

variable "database_max_allocated_storage" {
  description = "The most storage, in GiB, RDS may grow the database to on its own. Equal to database_allocated_storage turns that off."
  type        = number
  default     = 200
}

variable "database_multi_az" {
  description = "Whether RDS keeps a standby copy of the database in a second availability zone and fails over to it."
  type        = bool
  default     = true
}

variable "database_backup_retention_days" {
  description = "How many days RDS keeps automated backups of the database."
  type        = number
  default     = 14

  validation {
    condition     = var.database_backup_retention_days >= 1 && var.database_backup_retention_days <= 35
    error_message = "database_backup_retention_days must be from 1 to 35."
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

variable "database_username" {
  description = "The database's master user, which Pathways connects as."
  type        = string
  default     = "pathways"

  validation {
    condition     = can(regex("^[a-z][a-z0-9_]{0,62}$", var.database_username))
    error_message = "database_username must be lowercase letters, digits and underscores, starting with a letter."
  }
}

variable "database_password_version" {
  description = "Raise this by one to set a new database password: the module generates one, sets it on the database and writes the new connection URL to its secret in the same run, and neither the plan nor the state ever holds it. Restart the engine afterwards so it reads the new secret. Raise it also when the password and the stored URL stop matching (the engine fails to log in): after the database was replaced, or after a first apply that created the database but failed before it wrote the secret."
  type        = number
  default     = 1

  validation {
    condition     = var.database_password_version >= 1 && floor(var.database_password_version) == var.database_password_version
    error_message = "database_password_version must be a whole number, 1 or more."
  }
}

variable "database_kms_key_arn" {
  description = "ARN of a KMS key of your own to encrypt the database's storage, its automated backups and its final snapshot. Null uses the module's key, which a destroy schedules for deletion with everything else: after kms_key_deletion_window_days the final snapshot cannot be restored. Give a key that outlives the module if the final snapshot must. Its key policy must let RDS use it for the role that applies."
  type        = string
  default     = null

  validation {
    condition     = var.database_kms_key_arn == null || can(regex("^arn:aws[a-z-]*:kms:[a-z0-9-]+:[0-9]{12}:key/[A-Za-z0-9-]+$", var.database_kms_key_arn))
    error_message = "database_kms_key_arn must be a KMS key ARN (arn:aws:kms:<region>:<account>:key/<id>), not an alias, or null."
  }
}

variable "database_url_secret_arn" {
  description = "ARN of a Secrets Manager secret of your own that holds the connection URL of an existing PostgreSQL database, to use it instead of the RDS instance the module creates. Given, the module creates no database, no subnet group and no URL secret, and the other database_ inputs do nothing; ECS injects this secret as PATHWAYS_DATABASE_URL. It needs database_security_group_id. If the secret is encrypted under a customer managed key, list the key in secrets_kms_key_arns. Null creates the database."
  type        = string
  default     = null

  validation {
    condition     = var.database_url_secret_arn == null || can(regex("^arn:aws[a-z-]*:secretsmanager:[a-z0-9-]+:[0-9]{12}:secret:.+$", var.database_url_secret_arn))
    error_message = "database_url_secret_arn must be the ARN of a Secrets Manager secret (arn:aws:secretsmanager:<region>:<account>:secret:<name>), never the URL itself, or null."
  }
}

variable "database_security_group_id" {
  description = "With database_url_secret_arn, the security group of the existing database. The module lets the engine reach it on 5432 and adds a rule to it that admits the engine on 5432. Give both or neither."
  type        = string
  default     = null

  validation {
    condition     = (var.database_security_group_id == null) == (var.database_url_secret_arn == null)
    error_message = "database_url_secret_arn and database_security_group_id go together: give both to use an existing database, or neither to have the module create one."
  }

  validation {
    condition     = var.database_security_group_id == null || can(regex("^sg-[0-9a-f]{8,17}$", var.database_security_group_id))
    error_message = "database_security_group_id must be a security group id, such as sg-0a1b2c3d4e5f60718, or null."
  }
}

variable "deletion_protection" {
  description = "Whether the database and the load balancers refuse deletion. Turn it off, and apply, before you destroy the module."
  type        = bool
  default     = true
}

# ---------------------------------------------------------------------------
# The bucket (optional)
# ---------------------------------------------------------------------------

variable "bucket_enabled" {
  description = "Whether to create an S3 bucket for the engine's file sources and destinations (modules/bucket): encrypted under the module's key, versioned, public access blocked, TLS only, with server access logs to a second bucket. The task role may list it and read, write and delete its objects, and the engine gets its name as PATHWAYS_BUCKET, so a channel's s3 block reads bucket: { env: PATHWAYS_BUCKET } with no credential. Off by default."
  type        = bool
  default     = false
}

variable "bucket_lifecycle_rules" {
  description = "The bucket's lifecycle rules, by id, each for the keys under prefix: expiration_days for current objects, noncurrent_version_expiration_days for replaced and deleted versions, abort_incomplete_multipart_upload_days. Null leaves an action out. Pathways deletes each object it reads, which in a versioned bucket leaves a noncurrent version: the default removes those after 30 days and unfinished uploads after 7."
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
}

variable "bucket_access_log_retention_days" {
  description = "How many days the log bucket keeps the bucket's server access logs."
  type        = number
  default     = 365
}

# ---------------------------------------------------------------------------
# SFTP (optional)
# ---------------------------------------------------------------------------

variable "sftp_enabled" {
  description = "Whether to create an AWS Transfer Family SFTP server in front of the bucket (modules/sftp), for partners who drop and pick up files: a VPC endpoint with no public address, reachable from sftp_allowed_cidr_blocks only, its users locked to their home prefixes. It needs bucket_enabled. Off by default."
  type        = bool
  default     = false

  validation {
    condition     = !var.sftp_enabled || var.bucket_enabled
    error_message = "sftp_enabled needs bucket_enabled: the SFTP users' homes are in the module's bucket."
  }
}

variable "sftp_allowed_cidr_blocks" {
  description = "The networks allowed to connect to the SFTP endpoint, on port 22. Needed when sftp_enabled is true. 0.0.0.0/0, and any other /0 block, is refused."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for c in var.sftp_allowed_cidr_blocks : can(cidrnetmask(c))])
    error_message = "Each sftp_allowed_cidr_blocks entry must be an IPv4 CIDR block, such as 10.20.0.0/16."
  }

  validation {
    condition     = alltrue([for c in var.sftp_allowed_cidr_blocks : !can(cidrnetmask(c)) || try(tonumber(split("/", c)[1]) > 0, false)])
    error_message = "sftp_allowed_cidr_blocks may not hold 0.0.0.0/0, or any /0 block: name the networks that may connect."
  }

  validation {
    condition     = !var.sftp_enabled || length(var.sftp_allowed_cidr_blocks) > 0
    error_message = "sftp_enabled needs at least one block in sftp_allowed_cidr_blocks: nothing may connect until you say who."
  }
}

variable "sftp_subnet_ids" {
  description = "Subnets for the SFTP endpoint. Null uses private_subnet_ids. The endpoint gets no Elastic IP, so it stays internal to the VPC."
  type        = list(string)
  default     = null

  validation {
    condition     = var.sftp_subnet_ids == null || try(length(var.sftp_subnet_ids) > 0, false)
    error_message = "sftp_subnet_ids needs at least one subnet, or null."
  }
}

variable "sftp_users" {
  description = "The SFTP users, by user name, each with its SSH public keys and the prefix in the bucket that is its home, such as partners/lab. A user sees its prefix as / and reaches nothing outside it. modules/sftp checks each name, key and prefix."
  type = map(object({
    public_keys = list(string)
    home_prefix = string
  }))
  default = {}
}

variable "sftp_security_policy_name" {
  description = "The Transfer Family security policy of the SFTP server: the SSH ciphers, key exchanges and MACs it offers."
  type        = string
  default     = "TransferSecurityPolicy-2024-01"
}

variable "alarms_enabled" {
  description = "Whether to alarm on the engine's own metrics (modules/alarms): a collector beside the engine in its task reads /metrics on the health endpoint with a token the module generates, keeps four metrics with no channel or destination name, writes them to CloudWatch, and four CloudWatch alarms publish to alarms_sns_topic_arn. Your pathways.yaml needs a health block on alarms_health_port. CloudWatch bills for the metrics, the alarms and the log lines, and Secrets Manager for the token's secret. Off by default: nothing is created and nothing is billed until you turn it on."
  type        = bool
  default     = false

  validation {
    condition     = !var.alarms_enabled || !contains(concat(keys(var.secrets), keys(var.environment)), "PATHWAYS_HEALTH_TOKEN")
    error_message = "With alarms_enabled the module generates the health endpoint's token and gives it to the engine as PATHWAYS_HEALTH_TOKEN: leave it out of secrets and environment."
  }
}

variable "alarms_sns_topic_arn" {
  description = "ARN of the SNS topic the alarms publish to, on alarm and on OK. Required when alarms_enabled is true. You create the topic and its subscriptions; if it is encrypted, its key must let CloudWatch use it."
  type        = string
  default     = null

  validation {
    condition     = var.alarms_sns_topic_arn == null ? true : can(regex("^arn:aws[a-z-]*:sns:[a-z0-9-]+:[0-9]{12}:[A-Za-z0-9_-]+(\\.fifo)?$", var.alarms_sns_topic_arn))
    error_message = "alarms_sns_topic_arn must be the ARN of an SNS topic, such as arn:aws:sns:us-east-1:123456789012:pathways-alarms."
  }

  validation {
    condition     = !var.alarms_enabled || var.alarms_sns_topic_arn != null
    error_message = "alarms_enabled needs alarms_sns_topic_arn: the alarms publish to a topic you create."
  }
}

variable "alarms_collector_image" {
  description = "The metrics collector's image, by digest: an OpenTelemetry collector with the prometheus receiver, the filter and metricstransform processors and the awsemf exporter, such as AWS Distro for OpenTelemetry, public.ecr.aws/aws-observability/aws-otel-collector:<version>@sha256:<digest>. Required when alarms_enabled is true. A tag alone is refused. Built for the cpu_architecture chosen."
  type        = string
  default     = null

  validation {
    condition     = var.alarms_collector_image == null ? true : can(regex("^[^@[:space:]]+@sha256:[0-9a-f]{64}$", var.alarms_collector_image))
    error_message = "alarms_collector_image must name the image by digest, ending in @sha256: and 64 lowercase hex digits."
  }

  validation {
    condition     = !var.alarms_enabled || var.alarms_collector_image != null
    error_message = "alarms_enabled needs alarms_collector_image, the collector's image by digest."
  }
}

variable "alarms_health_port" {
  description = "The port of the engine's health endpoint, the health block of your pathways.yaml, which serves /metrics. The collector reads it at 127.0.0.1 inside the task, so the block keeps its default host, 127.0.0.1, with plaintext: true; the port is not mapped and nothing outside the task reaches it. Used when alarms_enabled is true."
  type        = number
  default     = 9090

  validation {
    condition     = var.alarms_health_port >= 1 && var.alarms_health_port <= 65535 && floor(var.alarms_health_port) == var.alarms_health_port
    error_message = "alarms_health_port must be a whole port from 1 to 65535."
  }

  validation {
    condition     = !var.alarms_enabled || !contains(concat([for s in values(var.mllp_sources) : s.port], [for s in values(var.http_sources) : s.port], [var.probe_port]), var.alarms_health_port)
    error_message = "alarms_health_port needs a port of its own: not an MLLP source's, an HTTP source's or the probe listener's."
  }
}

variable "alarms_health_token_version" {
  description = "Raise this by one to write a new health token: the module generates one and writes it to its secret, and neither the plan nor the state ever holds it. The engine and the collector read it when a task starts, so force a new deployment of the service after you raise it."
  type        = number
  default     = 1

  validation {
    condition     = var.alarms_health_token_version >= 1 && floor(var.alarms_health_token_version) == var.alarms_health_token_version
    error_message = "alarms_health_token_version must be a whole number, 1 or more."
  }
}

variable "alarms_store_down_minutes" {
  description = "How many minutes in a row pathways_store_up must be below 1, or missing, before the store down alarm fires. Missing counts, so an engine or a collector that stopped reporting fires it too."
  type        = number
  default     = 2

  validation {
    condition     = var.alarms_store_down_minutes >= 1 && var.alarms_store_down_minutes <= 60 && floor(var.alarms_store_down_minutes) == var.alarms_store_down_minutes
    error_message = "alarms_store_down_minutes must be a whole number from 1 to 60."
  }
}

variable "alarms_oldest_pending_age_seconds" {
  description = "The oldest pending age alarm fires when the oldest delivery waiting on any destination has waited longer than this, in seconds, for 5 minutes in a row."
  type        = number
  default     = 600

  validation {
    condition     = var.alarms_oldest_pending_age_seconds >= 0
    error_message = "alarms_oldest_pending_age_seconds must be 0 or more."
  }
}

variable "alarms_refused_messages_threshold" {
  description = "The refused messages alarm fires when the bodies the sources refused (unreadable or rejected, all channels together) number more than this in 15 minutes. 0 fires on the first one."
  type        = number
  default     = 0

  validation {
    condition     = var.alarms_refused_messages_threshold >= 0 && floor(var.alarms_refused_messages_threshold) == var.alarms_refused_messages_threshold
    error_message = "alarms_refused_messages_threshold must be a whole number, 0 or more."
  }
}

variable "alarms_settled_failed_threshold" {
  description = "The settled destinations failing alarm fires when the messages that settled as failed with a destination (all channels and destinations together) number more than this in 15 minutes. 0 fires on the first one."
  type        = number
  default     = 0

  validation {
    condition     = var.alarms_settled_failed_threshold >= 0 && floor(var.alarms_settled_failed_threshold) == var.alarms_settled_failed_threshold
    error_message = "alarms_settled_failed_threshold must be a whole number, 0 or more."
  }
}
