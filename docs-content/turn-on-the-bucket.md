---
id: turn-on-the-bucket
title: Turn on the S3 bucket
sidebar_label: Turn on the bucket
description: "Give the engine an encrypted, private S3 bucket for its file sources and destinations, reached through its task role with no access key."
---

# Turn on the S3 bucket

The module can create an S3 bucket for the engine's file sources and destinations. The engine's task
role may use it, and the engine gets its name as `PATHWAYS_BUCKET`, so a channel names it without a
credential.

## Turn it on

```hcl title="main.tf"
module "pathways" {
  source = "github.com/cosyte/terraform-aws-pathways?ref=<commit or tag>"
  # ...the inputs you already set

  bucket_enabled = true
}
```

After the apply, the bucket's name is in the `bucket_name` output. The service gets a new task
definition revision with `PATHWAYS_BUCKET` set, and ECS replaces the engine.

## Name it in a channel

A file source or destination's `s3` block names the bucket by that variable and nothing else: the AWS
SDK finds the task role and the region on its own.

```yaml title="channels/adt-to-lab/channel.yaml"
destinations:
  - file:
      dir: partners/lab/outbox
      s3:
        bucket: { env: PATHWAYS_BUCKET }
```

The Pathways docs cover the `s3` block in
[Read and write Amazon S3](https://docs.cosyte.com/pathways/read-and-write-amazon-s3).

## Set the lifecycle rules

The bucket is versioned. Pathways deletes each object it reads, which in a versioned bucket leaves a
noncurrent version, so the default rule removes noncurrent versions after 30 days and unfinished
multipart uploads after 7. Give your own rules, by id, each for the keys under its `prefix`:

```hcl title="main.tf"
  bucket_lifecycle_rules = {
    default = {
      noncurrent_version_expiration_days     = 30
      abort_incomplete_multipart_upload_days = 7
    }
    outbox = {
      prefix          = "partners/lab/outbox/"
      expiration_days = 90
    }
  }
```

Setting `bucket_lifecycle_rules` replaces the default rule, so keep a rule like `default` above.

## What you get

- Encryption under the module's KMS key, with an S3 Bucket Key, which lowers the requests S3 makes to
  KMS.
- All four Block Public Access settings on, and ACLs off.
- A bucket policy that refuses any request without TLS 1.2 or later.
- Server access logs to a second, private bucket, kept for `bucket_access_log_retention_days` (365 by
  default). Its name is in the `bucket_access_logs_bucket_name` output.
- On the task role: list the bucket, and read, write and delete its objects. Nothing else.

## What it costs

S3 bills per GB-month stored, noncurrent versions included until a lifecycle rule removes them, and
per request. A file source lists its prefix every `pollInterval`, so its list requests run all month
even when no file arrives. The access logs are objects in the log bucket, billed the same way.

## Related

- [Give partners SFTP](./give-partners-sftp.md), which needs the bucket.
- [The bucket submodule](./module-bucket.md), and the bucket inputs in
  [Inputs and outputs](./inputs-and-outputs.md#bucket_enabled).
