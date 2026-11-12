---
id: module-alarms
title: The alarms submodule
sidebar_label: alarms
description: "Every input and output of modules/alarms, generated from its code."
---

# The alarms submodule

`modules/alarms` holds the optional alarms on the engine's metrics, the health token and the collector's configuration. The root module calls it; to use it on its own, set `source = "github.com/cosyte/terraform-aws-pathways//modules/alarms"`.

This page is generated from the code by `scripts/docs.sh`, and CI fails when it no longer matches, so it lists every input and output there is. Edit the descriptions in the `.tf` files, never here.

## Required inputs

### name

Name of the deployment. The alarms are pathways-\<name\>-\<alarm\>, the token's secret pathways/\<name\>/health-token, and each metric carries the dimension Deployment = \<name\>.

Type: `string`

Required: it has no default.

### log_group_prefix

The prefix of the deployment's log groups. The collector writes the metrics, as CloudWatch embedded metric format lines, to \<prefix\>/metrics. The key's policy must let CloudWatch Logs use it under this prefix.

Type: `string`

Required: it has no default.

### kms_key_arn

ARN of the customer managed KMS key that encrypts the metrics log group and the health token's secret. Its key policy must let IAM policies in the account grant its use, as the kms submodule's does.

Type: `string`

Required: it has no default.

### task_role_name

Name of the role the engine's task runs as. The collector runs as it too, so it gets logs:CreateLogStream and logs:PutLogEvents on the metrics log group, and nothing else.

Type: `string`

Required: it has no default.

### sns_topic_arn

ARN of the SNS topic each alarm publishes to when it goes into alarm and when it comes back to OK. You create the topic and its subscriptions; if it is encrypted, its key must let CloudWatch use it.

Type: `string`

Required: it has no default.

## Optional inputs

### log_retention_days

How many days CloudWatch Logs keeps the metrics log group's lines. They hold the four metrics the alarms read, with no channel or destination name.

Type: `number`

Default: `365`

### health_port

The port of the engine's health endpoint, the health block of your pathways.yaml, which serves /metrics. The collector reads it at 127.0.0.1 inside the task, so the block can keep its default host, 127.0.0.1.

Type: `number`

Default: `9090`

### health_token_version

Raise this by one to write a new health token: the module generates one and writes it to its secret, and neither the plan nor the state ever holds it. The engine and the collector read it when a task starts, so force a new deployment of the service after you raise it.

Type: `number`

Default: `1`

### store_down_minutes

How many minutes in a row pathways_store_up must be below 1, or missing, before the store down alarm fires. Missing counts: an engine or a collector that stopped reporting fires it too.

Type: `number`

Default: `2`

### oldest_pending_age_seconds

The oldest pending age alarm fires when the oldest delivery waiting on any destination has waited longer than this, in seconds, for 5 minutes in a row.

Type: `number`

Default: `600`

### refused_messages_threshold

The refused messages alarm fires when the bodies the sources refused (unreadable or rejected, all channels together) number more than this in 15 minutes. 0 fires on the first one.

Type: `number`

Default: `0`

### settled_failed_threshold

The settled destinations failing alarm fires when the messages that settled as failed with a destination (all channels and destinations together) number more than this in 15 minutes. 0 fires on the first one.

Type: `number`

Default: `0`

### tags

Tags added to every resource the module creates. The caller's provider default_tags apply as well.

Type: `map(string)`

Default: `{}`

## Outputs

### health_token_secret_arn

ARN of the Secrets Manager secret that holds the health endpoint's bearer token. ECS injects it into the engine and the collector as PATHWAYS_HEALTH_TOKEN; the execution role must be allowed to read it. The token itself is in no output, no plan and no state.

### health_token_variable

The environment variable the engine's health endpoint and the collector read the token from.

### collector_config

The OpenTelemetry collector's configuration, in YAML: scrape /metrics at 127.0.0.1 on the health port, keep the four families, fold their labels away, and write them to the metrics log group. It names the token only as the variable it is read from.

### metrics_log_group_name

Name of the log group the collector writes the metrics to, as CloudWatch embedded metric format lines.

### metrics_log_group_arn

ARN of the log group the collector writes the metrics to.

### namespace

The CloudWatch namespace of the metrics. Each carries the one dimension Deployment, the deployment's name.

### alarm_arns

ARNs of the four alarms, by key: store_down, oldest_pending_age, refused_messages and settled_failed.
