---
id: module-kms
title: The kms submodule
sidebar_label: kms
description: "Every input and output of modules/kms, generated from its code."
---

# The kms submodule

`modules/kms` holds the customer managed key, rotated yearly. The root module calls it; to use it on its own, set `source = "github.com/cosyte/terraform-aws-pathways//modules/kms"`.

This page is generated from the code by `scripts/docs.sh`, and CI fails when it no longer matches, so it lists every input and output there is. Edit the descriptions in the `.tf` files, never here.

## Required inputs

### name

Name of the deployment. The key's description and its alias, alias/pathways-\<name\>, are made from it.

Type: `string`

Required: it has no default.

### log_group_prefix

The prefix of the log groups CloudWatch Logs may encrypt with the key, such as /pathways/\<name\>. Log groups outside it cannot use the key.

Type: `string`

Required: it has no default.

## Optional inputs

### deletion_window_days

Days between scheduling the key for deletion and its deletion, 7 to 30 (AWS allows no more). Everything it encrypts is unreadable after that.

Type: `number`

Default: `30`

### tags

Tags added to the key. The caller's provider default_tags apply as well.

Type: `map(string)`

Default: `{}`

## Outputs

### key_arn

ARN of the customer managed KMS key.

### key_id

ID of the customer managed KMS key.

### alias_name

The key's alias, alias/pathways-\<name\>.
