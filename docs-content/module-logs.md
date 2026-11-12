---
id: module-logs
title: The logs submodule
sidebar_label: logs
description: "Every input and output of modules/logs, generated from its code."
---

# The logs submodule

`modules/logs` holds the engine's and the migrate task's log groups. The root module calls it; to use it on its own, set `source = "github.com/cosyte/terraform-aws-pathways//modules/logs"`.

This page is generated from the code by `scripts/docs.sh`, and CI fails when it no longer matches, so it lists every input and output there is. Edit the descriptions in the `.tf` files, never here.

## Required inputs

### log_group_prefix

The prefix of both log groups: \<prefix\>/engine and \<prefix\>/migrate. The key's policy must let CloudWatch Logs use it under this prefix.

Type: `string`

Required: it has no default.

### kms_key_arn

ARN of the customer managed KMS key that encrypts both log groups.

Type: `string`

Required: it has no default.

## Optional inputs

### retention_days

How many days CloudWatch Logs keeps the engine's and the migrate task's logs. They hold ids, counts and codes, never message content.

Type: `number`

Default: `365`

### tags

Tags added to both log groups. The caller's provider default_tags apply as well.

Type: `map(string)`

Default: `{}`

## Outputs

### engine_log_group_name

Name of the engine's CloudWatch log group.

### engine_log_group_arn

ARN of the engine's CloudWatch log group.

### migrate_log_group_name

Name of the migrate task's CloudWatch log group.

### migrate_log_group_arn

ARN of the migrate task's CloudWatch log group.
