---
id: module-bucket
title: The bucket submodule
sidebar_label: bucket
description: "Every input and output of modules/bucket, generated from its code."
---

# The bucket submodule

`modules/bucket` holds the optional S3 bucket, its access log bucket and the task role's access. The root module calls it; to use it on its own, set `source = "github.com/cosyte/terraform-aws-pathways//modules/bucket"`.

This page is generated from the code by `scripts/docs.sh`, and CI fails when it no longer matches, so it lists every input and output there is. Edit the descriptions in the `.tf` files, never here.

## Required inputs

### name

Name of the deployment. The bucket's name starts pathways-\<name\>-, the log bucket's \<name\>-access-logs-, and S3 adds a unique suffix to each.

Type: `string`

Required: it has no default.

### kms_key_arn

ARN of the customer managed KMS key the bucket's objects are encrypted under (SSE-KMS, with an S3 Bucket Key). Its key policy must let IAM policies in the account grant its use, as the kms submodule's does.

Type: `string`

Required: it has no default.

## Optional inputs

### lifecycle_rules

Lifecycle rules, by id, each for the keys under prefix ("" for all): days until a current object expires, days until a replaced or deleted (noncurrent) version is removed, and days until an unfinished multipart upload is aborted. Null leaves that action out. The bucket is versioned, so an object Pathways deletes after reading stays as a noncurrent version until a rule removes it. The default removes noncurrent versions after 30 days and unfinished uploads after 7, and never expires a current object. An empty map sets no rule.

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

### access_log_retention_days

How many days the log bucket keeps the bucket's server access logs. They name each object's key and who asked for it, never an object's content; a key a sender chooses can still carry what a file name carries.

Type: `number`

Default: `365`

### task_role_name

Name of the role the Pathways tasks run as, which gets an inline policy to list the bucket, read, write and delete its objects, and use the key for them. Null attaches nothing.

Type: `string`

Default: `null`

### tags

Tags added to both buckets. The caller's provider default_tags apply as well.

Type: `map(string)`

Default: `{}`

## Outputs

### bucket_name

Name of the bucket, for the bucket key of a Pathways s3 block.

### bucket_arn

ARN of the bucket.

### access_logs_bucket_name

Name of the bucket that receives the bucket's server access logs, under the prefix \<bucket name\>/.

### task_policy_json

The policy the task role gets: list the bucket, read, write and delete its objects, and use the key for them through S3. Attach it to another role that needs the same access.

### task_policy_role_name

Name of the role the module gave the bucket's policy to, or null when task_role_name is null.
