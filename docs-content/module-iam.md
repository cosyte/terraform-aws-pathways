---
id: module-iam
title: The iam submodule
sidebar_label: iam
description: "Every input and output of modules/iam, generated from its code."
---

# The iam submodule

`modules/iam` holds the task execution role and the task role. The root module calls it; to use it on its own, set `source = "github.com/cosyte/terraform-aws-pathways//modules/iam"`.

This page is generated from the code by `scripts/docs.sh`, and CI fails when it no longer matches, so it lists every input and output there is. Edit the descriptions in the `.tf` files, never here.

## Required inputs

### name

Name of the deployment. The roles are pathways-\<name\>-execution and pathways-\<name\>-task.

Type: `string`

Required: it has no default.

### images

The images the tasks run, by digest. Each one in ECR lets the execution role pull from its own repository, and no other; an image outside ECR gives no ECR permission. Null entries are skipped.

Type: `list(string)`

Required: it has no default.

### log_group_arns

ARNs of the CloudWatch log groups the tasks' awslogs driver writes to.

Type: `list(string)`

Required: it has no default.

## Optional inputs

### secrets

The secrets ECS injects into the tasks, by variable name, each the ARN of a Secrets Manager secret (optionally with :json-key:: and a version suffix) or of an SSM parameter. The execution role may read exactly these.

Type: `map(string)`

Default: `{}`

### repository_credentials_secret_arn

ARN of a Secrets Manager secret holding a username and password for a private registry other than ECR, which the execution role may read. Null for ECR or a public image.

Type: `string`

Default: `null`

### kms_key_arns

ARNs of the customer managed KMS keys that encrypt the secrets, which the execution role may decrypt with.

Type: `list(string)`

Default: `[]`

### tags

Tags added to both roles. The caller's provider default_tags apply as well.

Type: `map(string)`

Default: `{}`

## Outputs

### execution_role_arn

ARN of the role ECS starts the tasks with.

### execution_role_name

Name of the role ECS starts the tasks with.

### task_role_arn

ARN of the role the tasks run as.

### task_role_name

Name of the role the tasks run as. It has no permissions: attach a policy for an extension that calls AWS.
