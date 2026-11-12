---
id: inputs-and-outputs
title: Inputs and outputs
sidebar_label: Inputs and outputs
description: "Every input and output of the root module, with its type, its default and what it does, generated from variables.tf and outputs.tf."
---

# Inputs and outputs

The root module's inputs, from `variables.tf`, and its outputs, from `outputs.tf`. Defaults are shown as JSON. The submodules each have a page of their own, for a caller who uses one on its own.

This page is generated from the code by `scripts/docs.sh`, and CI fails when it no longer matches, so it lists every input and output there is. Edit the descriptions in the `.tf` files, never here.

## Required inputs

### vpc_id

The VPC the engine, its database and its load balancers run in.

Type: `string`

Required: it has no default.

### private_subnet_ids

Private subnets for the engine's tasks, in at least two availability zones. The tasks get no public IP address.

Type: `list(string)`

Required: it has no default.

### allowed_cidr_blocks

The networks allowed to connect to the MLLP and HTTP sources through the load balancers: your senders' addresses, or your VPN's. There is no default, so nothing is open until you say what is.

Type: `list(string)`

Required: it has no default.

### image

Your project's own image, built on the Pathways image with your channels inside it, named by digest: registry/repository:tag@sha256:\<64 hex digits\>, or registry/repository@sha256:\<digest\>. A tag alone is refused, so a deploy always runs exactly the image you tested.

Type: `string`

Required: it has no default.

## Optional inputs

### name

Name of this deployment. Every resource the module creates is named from it, so two deployments in one account and region need two names.

Type: `string`

Default: `"pathways"`

### tags

Tags added to every resource the module creates. The caller's provider default_tags apply as well.

Type: `map(string)`

Default: `{}`

### database_subnet_ids

Subnets for the database, in at least two availability zones. Null uses private_subnet_ids.

Type: `list(string)`

Default: `null`

### load_balancer_subnet_ids

Subnets for the load balancers. Null uses private_subnet_ids. An internet-facing load balancer (load_balancer_internal = false) needs public subnets here.

Type: `list(string)`

Default: `null`

### load_balancer_internal

Whether the load balancers are internal, reachable only from inside the VPC and what is connected to it. The default; set false only with public subnets and a narrow allowed_cidr_blocks.

Type: `bool`

Default: `true`

### egress_rules

Where the engine's tasks may connect, other than the database, which is always allowed: each rule is a TCP port and the networks it may reach. The default allows HTTPS anywhere, which the tasks need for the image registry, Secrets Manager and CloudWatch Logs through a NAT gateway; with VPC endpoints for those, narrow it. Add a rule for each destination's port.

Type:

```hcl
map(object({
    port        = number
    cidr_blocks = list(string)
  }))
```

Default:

```json
{
  "https": {
    "cidr_blocks": [
      "0.0.0.0/0"
    ],
    "port": 443
  }
}
```

### migrate_image

The image the migrate task definition runs, by digest. Null runs image. A deploy that moves the schema sets it to the new image first, runs the migrate task, then moves image: see the README's Deploy section.

Type: `string`

Default: `null`

### repository_credentials_secret_arn

ARN of a Secrets Manager secret holding a username and password for a private registry other than ECR. Null for ECR, which the execution role reads, or a public image.

Type: `string`

Default: `null`

### cpu

CPU units for each engine task, 1024 to a vCPU. Raise it, with memory, to scale the engine up: one engine runs per database.

Type: `number`

Default: `1024`

### memory

Memory for each engine task, in MiB. It must be a size Fargate allows for the cpu chosen; AWS refuses the task definition otherwise.

Type: `number`

Default: `2048`

### cpu_architecture

The CPU architecture of the tasks: X86_64 or ARM64. The Pathways image is published for both; your project's image must be built for the one chosen.

Type: `string`

Default: `"X86_64"`

### mllp_sources

The MLLP sources of your pathways.yaml, by name, each with the port it listens on. Each gets a TCP listener on the network load balancer, on the same port, passed through to the engine, which terminates its own TLS. Empty creates no network load balancer.

Type:

```hcl
map(object({
    port = number
  }))
```

Default: `{}`

### http_sources

The HTTP sources of your pathways.yaml, by name, each with the port it listens on. Each gets an HTTPS listener on the application load balancer, on the same port, forwarding to the engine with http_target_protocol. Empty creates no application load balancer.

Type:

```hcl
map(object({
    port = number
  }))
```

Default: `{}`

### http_target_protocol

How the application load balancer reaches the engine's HTTP sources: HTTPS, to an HTTP source with its own tls block (the default), or HTTP, to one with plaintext: true.

Type: `string`

Default: `"HTTPS"`

### alb_certificate_arn

ARN of the ACM certificate the application load balancer's HTTPS listeners present. Needed when http_sources is not empty.

Type: `string`

Default: `null`

### alb_ssl_policy

The TLS policy of the application load balancer's HTTPS listeners.

Type: `string`

Default: `"ELBSecurityPolicy-TLS13-1-2-2021-06"`

### probe_port

The port of the probe listener, the probes block of your pathways.yaml. The load balancers check /readyz on it, and the container health check runs pathways probe, which asks /livez. The block must set host: 0.0.0.0 so the load balancers reach it.

Type: `number`

Default: `9091`

### drain_timeout_seconds

How long a stopping engine has to drain: the load balancers' deregistration delay, and then the container's stop timeout, the time between SIGTERM and SIGKILL. Fargate allows a stop timeout of at most 120 seconds.

Type: `number`

Default: `60`

### health_check_grace_period_seconds

How long ECS waits after a task starts before it acts on the load balancers' health checks: long enough for the engine to start, take the lease and turn ready.

Type: `number`

Default: `120`

### environment

Plain settings for the engine, as environment variables your pathways.yaml reads with \{ env: NAME \}: ports, hosts, durations, the storage kind. Never a secret: those go in secrets.

Type: `map(string)`

Default: `{}`

### secrets

Secrets for the engine, as environment variables, each the ARN of a Secrets Manager secret (optionally with :json-key:: and a version suffix) or of an SSM parameter. ECS reads each when the task starts and sets the variable, so pathways.yaml reads it with \{ env: NAME \}. The master key goes here, such as PATHWAYS_KEY_2026_11. The module sets PATHWAYS_DATABASE_URL itself.

Type: `map(string)`

Default: `{}`

### secrets_kms_key_arns

ARNs of customer managed KMS keys that encrypt the secrets you pass in secrets, so the task execution role may decrypt them. The module's own key is always included.

Type: `list(string)`

Default: `[]`

### container_insights

Whether the ECS cluster runs Container Insights. It writes performance metrics only (CPU, memory, network, task counts), never message content, to a log group AWS creates, /aws/ecs/containerinsights/\<cluster\>/performance, which is not encrypted under the module's key and is billed by CloudWatch. Off by default.

Type: `bool`

Default: `false`

### log_retention_days

How many days CloudWatch Logs keeps the engine's and the migrate task's logs. They hold ids, counts and codes, never message content.

Type: `number`

Default: `365`

### kms_key_deletion_window_days

Days between scheduling the module's KMS key for deletion and its deletion, 7 to 30 (AWS allows no more). Everything it encrypts is unreadable after that, the database's final snapshot included unless database_kms_key_arn names a key of your own.

Type: `number`

Default: `30`

### database_engine_version

The PostgreSQL version of the RDS instance, a major version such as 17, or a full one.

Type: `string`

Default: `"17"`

### database_parameter_group_family

The parameter group family matching database_engine_version, such as postgres17.

Type: `string`

Default: `"postgres17"`

### database_instance_class

The RDS instance class of the database.

Type: `string`

Default: `"db.t4g.medium"`

### database_allocated_storage

The database's starting storage, in GiB.

Type: `number`

Default: `50`

### database_max_allocated_storage

The most storage, in GiB, RDS may grow the database to on its own. Equal to database_allocated_storage turns that off.

Type: `number`

Default: `200`

### database_multi_az

Whether RDS keeps a standby copy of the database in a second availability zone and fails over to it.

Type: `bool`

Default: `true`

### database_backup_retention_days

How many days RDS keeps automated backups of the database.

Type: `number`

Default: `14`

### database_name

The name of the database Pathways stores messages in.

Type: `string`

Default: `"pathways"`

### database_username

The database's master user, which Pathways connects as.

Type: `string`

Default: `"pathways"`

### database_password_version

Raise this by one to set a new database password: the module generates one, sets it on the database and writes the new connection URL to its secret in the same run, and neither the plan nor the state ever holds it. Restart the engine afterwards so it reads the new secret. Raise it also when the password and the stored URL stop matching (the engine fails to log in): after the database was replaced, or after a first apply that created the database but failed before it wrote the secret.

Type: `number`

Default: `1`

### database_kms_key_arn

ARN of a KMS key of your own to encrypt the database's storage, its automated backups and its final snapshot. Null uses the module's key, which a destroy schedules for deletion with everything else: after kms_key_deletion_window_days the final snapshot cannot be restored. Give a key that outlives the module if the final snapshot must. Its key policy must let RDS use it for the role that applies.

Type: `string`

Default: `null`

### deletion_protection

Whether the database and the load balancers refuse deletion. Turn it off, and apply, before you destroy the module.

Type: `bool`

Default: `true`

### bucket_enabled

Whether to create an S3 bucket for the engine's file sources and destinations (modules/bucket): encrypted under the module's key, versioned, public access blocked, TLS only, with server access logs to a second bucket. The task role may list it and read, write and delete its objects, and the engine gets its name as PATHWAYS_BUCKET, so a channel's s3 block reads bucket: \{ env: PATHWAYS_BUCKET \} with no credential. Off by default.

Type: `bool`

Default: `false`

### bucket_lifecycle_rules

The bucket's lifecycle rules, by id, each for the keys under prefix: expiration_days for current objects, noncurrent_version_expiration_days for replaced and deleted versions, abort_incomplete_multipart_upload_days. Null leaves an action out. Pathways deletes each object it reads, which in a versioned bucket leaves a noncurrent version: the default removes those after 30 days and unfinished uploads after 7.

Type:

```hcl
map(object({
    prefix                                 = optional(string, "")
    expiration_days                        = optional(number)
    noncurrent_version_expiration_days     = optional(number)
    abort_incomplete_multipart_upload_days = optional(number)
  }))
```

Default:

```json
{
  "default": {
    "abort_incomplete_multipart_upload_days": 7,
    "noncurrent_version_expiration_days": 30
  }
}
```

### bucket_access_log_retention_days

How many days the log bucket keeps the bucket's server access logs.

Type: `number`

Default: `365`

### sftp_enabled

Whether to create an AWS Transfer Family SFTP server in front of the bucket (modules/sftp), for partners who drop and pick up files: a VPC endpoint with no public address, reachable from sftp_allowed_cidr_blocks only, its users locked to their home prefixes. It needs bucket_enabled. Off by default.

Type: `bool`

Default: `false`

### sftp_allowed_cidr_blocks

The networks allowed to connect to the SFTP endpoint, on port 22. Needed when sftp_enabled is true. 0.0.0.0/0, and any other /0 block, is refused.

Type: `list(string)`

Default: `[]`

### sftp_subnet_ids

Subnets for the SFTP endpoint. Null uses private_subnet_ids. The endpoint gets no Elastic IP, so it stays internal to the VPC.

Type: `list(string)`

Default: `null`

### sftp_users

The SFTP users, by user name, each with its SSH public keys and the prefix in the bucket that is its home, such as partners/lab. A user sees its prefix as / and reaches nothing outside it. modules/sftp checks each name, key and prefix.

Type:

```hcl
map(object({
    public_keys = list(string)
    home_prefix = string
  }))
```

Default: `{}`

### sftp_security_policy_name

The Transfer Family security policy of the SFTP server: the SSH ciphers, key exchanges and MACs it offers.

Type: `string`

Default: `"TransferSecurityPolicy-2024-01"`

## Outputs

### cluster_arn

ARN of the ECS cluster.

### cluster_name

Name of the ECS cluster.

### service_name

Name of the ECS service that runs the engine.

### engine_task_definition_arn

ARN of the engine's task definition, at its current revision.

### migrate_task_definition_arn

ARN of the migrate task definition, at its current revision. CI runs it with ECS RunTask, on the image it is about to deploy, and waits for it to exit 0 before it applies that image to the service.

### migrate_network_configuration

The network configuration for an ECS RunTask of the migrate task definition, as the JSON aws ecs run-task --network-configuration takes: the private subnets and the engine's security group, which the database admits.

### engine_security_group_id

ID of the engine's security group. The database admits it; add rules to it, or to a destination's own group, for anything else the engine reaches.

### task_role_name

Name of the role the engine and migrate tasks run as. It has no permissions but the bucket's, when bucket_enabled is true: attach a policy for an extension that calls AWS.

### task_role_arn

ARN of the role the engine and migrate tasks run as.

### execution_role_arn

ARN of the role ECS starts the tasks with. A CI role that runs the migrate task needs iam:PassRole on it and on task_role_arn.

### kms_key_arn

ARN of the customer managed KMS key that encrypts the database, its secret and the logs.

### database_address

Hostname of the PostgreSQL instance. Connections must use TLS, verified against the RDS certificate authority.

### database_url_secret_arn

ARN of the Secrets Manager secret holding the database's connection URL, which ECS injects as PATHWAYS_DATABASE_URL.

### engine_log_group_name

Name of the engine's CloudWatch log group.

### migrate_log_group_name

Name of the migrate task's CloudWatch log group.

### nlb_dns_name

DNS name of the network load balancer for the MLLP sources, or null when there is none.

### nlb_zone_id

Hosted zone ID of the network load balancer, for a Route 53 alias record, or null.

### alb_dns_name

DNS name of the application load balancer for the HTTP sources, or null when there is none.

### alb_zone_id

Hosted zone ID of the application load balancer, for a Route 53 alias record, or null.

### bucket_name

Name of the S3 bucket, which the engine gets as PATHWAYS_BUCKET, or null when bucket_enabled is false.

### bucket_arn

ARN of the S3 bucket, or null when bucket_enabled is false.

### bucket_access_logs_bucket_name

Name of the bucket that receives the S3 bucket's server access logs, or null.

### sftp_server_id

ID of the Transfer Family SFTP server, or null when sftp_enabled is false.

### sftp_endpoint

The SFTP server's hostname, or null.

### sftp_vpc_endpoint_id

ID of the SFTP server's VPC endpoint, whose DNS names and private addresses clients inside the VPC connect to, or null.

### sftp_security_group_id

ID of the SFTP endpoint's security group, or null.

### sftp_log_group_name

Name of the SFTP server's CloudWatch log group, or null.
