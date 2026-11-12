---
id: module-ecs
title: The ecs submodule
sidebar_label: ecs
description: "Every input and output of modules/ecs, generated from its code."
---

# The ecs submodule

`modules/ecs` holds the cluster, the engine and migrate task definitions, and the service. The root module calls it; to use it on its own, set `source = "github.com/cosyte/terraform-aws-pathways//modules/ecs"`.

This page is generated from the code by `scripts/docs.sh`, and CI fails when it no longer matches, so it lists every input and output there is. Edit the descriptions in the `.tf` files, never here.

## Required inputs

### name

Name of the deployment. The cluster is pathways-\<name\>, and the task definitions and the service are named from it.

Type: `string`

Required: it has no default.

### image

The engine's image, named by digest: registry/repository:tag@sha256:\<64 hex digits\>, or registry/repository@sha256:\<digest\>. A tag alone is refused.

Type: `string`

Required: it has no default.

### container_ports

Every port the engine container listens on: each source's, and the probe listener's.

Type: `list(number)`

Required: it has no default.

### execution_role_arn

ARN of the role ECS starts the tasks with: it pulls the image, reads the secrets and writes the logs.

Type: `string`

Required: it has no default.

### task_role_arn

ARN of the role the tasks run as.

Type: `string`

Required: it has no default.

### engine_log_group_name

Name of the CloudWatch log group the engine's awslogs driver writes to.

Type: `string`

Required: it has no default.

### migrate_log_group_name

Name of the CloudWatch log group the migrate task's awslogs driver writes to.

Type: `string`

Required: it has no default.

### subnet_ids

Private subnets for the engine's tasks. The tasks get no public IP address.

Type: `list(string)`

Required: it has no default.

### security_group_ids

The security groups of the engine's tasks.

Type: `list(string)`

Required: it has no default.

## Optional inputs

### migrate_image

The image the migrate task definition runs, by digest. Null runs image.

Type: `string`

Default: `null`

### repository_credentials_secret_arn

ARN of a Secrets Manager secret holding a username and password for a private registry other than ECR. Null for ECR or a public image.

Type: `string`

Default: `null`

### cpu

CPU units for each task, 1024 to a vCPU.

Type: `number`

Default: `1024`

### memory

Memory for each task, in MiB. It must be a size Fargate allows for the cpu chosen; AWS refuses the task definition otherwise.

Type: `number`

Default: `2048`

### cpu_architecture

The CPU architecture of the tasks: X86_64 or ARM64. The image must be built for the one chosen.

Type: `string`

Default: `"X86_64"`

### environment

Plain settings for the engine, as environment variables. Never a secret: those go in secrets.

Type: `map(string)`

Default: `{}`

### secrets

Secrets for the engine, as environment variables, each the ARN of a Secrets Manager secret (optionally with :json-key:: and a version suffix) or of an SSM parameter, which ECS reads when the task starts. The execution role must be allowed to read each.

Type: `map(string)`

Default: `{}`

### drain_timeout_seconds

The engine container's stop timeout, the time between SIGTERM and SIGKILL. Fargate allows at most 120 seconds.

Type: `number`

Default: `60`

### health_check_grace_period_seconds

How long ECS waits after a task starts before it acts on the load balancers' health checks. Unused when load_balancers is empty.

Type: `number`

Default: `120`

### container_insights

Whether the cluster runs Container Insights. It writes performance metrics only, never message content, to a log group AWS creates, which is not encrypted under your key and is billed by CloudWatch. Off by default.

Type: `bool`

Default: `false`

### load_balancers

The target groups the service registers the engine with, by any key, each with the container port it forwards to. Empty runs the service with no load balancer.

Type:

```hcl
map(object({
    target_group_arn = string
    container_port   = number
  }))
```

Default: `{}`

### metrics_collector

A metrics collector to run beside the engine in its task, which reads the engine's /metrics over the task's loopback: its image by digest, its configuration (passed as PATHWAYS_COLLECTOR_CONFIG and read with --config=env:PATHWAYS_COLLECTOR_CONFIG, as an OpenTelemetry collector takes it), and the Secrets Manager secret of the health endpoint's bearer token, which ECS injects into the engine and the collector as PATHWAYS_HEALTH_TOKEN. The execution role must be allowed to read it. Null runs the engine alone.

Type:

```hcl
object({
    image            = string
    config           = string
    token_secret_arn = string
  })
```

Default: `null`

### tags

Tags added to every resource the module creates. The caller's provider default_tags apply as well.

Type: `map(string)`

Default: `{}`

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

ARN of the migrate task definition, at its current revision.

### engine_container

The engine's container definition, as the task definition gives it to ECS. Secrets appear as the ARNs ECS reads them from, never as values.

### migrate_container

The migrate task's container definition, as the task definition gives it to ECS.

### metrics_collector_container

The metrics collector's container definition, as the engine's task definition gives it to ECS, or null with no metrics_collector. The health token appears as the ARN ECS reads it from, never as its value.

### engine_task_container_definitions

The engine task definition's container definitions, the JSON ECS gets: the engine alone, or the engine and the metrics collector.
