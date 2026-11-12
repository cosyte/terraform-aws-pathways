# bucket

An S3 bucket for a Pathways file source or destination (a `file` block with `s3:`), with a second
bucket for its server access logs, and a policy for the role the engine runs as. The root module
calls it when `bucket_enabled` is true.

- **Encrypted** under the KMS key you give (SSE-KMS), with an S3 Bucket Key, which cuts the requests
  S3 makes to KMS.
- **Private**: all four public access block settings on, and ACLs off (`BucketOwnerEnforced`).
- **TLS only**: the bucket policy denies any request without TLS, and any below TLS 1.2. It grants
  nothing.
- **Versioned**, with `lifecycle_rules`. Pathways deletes each object it reads, which in a versioned
  bucket leaves a noncurrent version: the default rule removes those after 30 days and unfinished
  multipart uploads after 7, and never expires a current object.
- **Access logs**: S3 server access logs go to a second bucket, private, versioned and TLS only,
  kept for `access_log_retention_days`. That bucket is encrypted with SSE-S3, not your key: server
  access logging delivers only to a bucket whose default encryption is SSE-S3. The logs name each
  object's key and who asked for it, never its content.
- **The task role** (`task_role_name`) gets `s3:ListBucket` on the bucket, `s3:GetObject`,
  `s3:PutObject` and `s3:DeleteObject` on its objects, the four calls a Pathways `s3` block makes,
  and `kms:GenerateDataKey` and `kms:Decrypt` on the key, through S3 and for this bucket only. No
  access key exists.

The names start `pathways-<name>-` and `<name>-access-logs-`, and S3 adds a unique suffix to each:
read them from the outputs.

```hcl
module "pathways_bucket" {
  source = "github.com/cosyte/terraform-aws-pathways//modules/bucket"

  name           = "integration"
  kms_key_arn    = module.pathways_kms.key_arn
  task_role_name = module.pathways_iam.task_role_name
}
```

It has no provider block: your `aws` provider and its region apply. Inputs are in
[`variables.tf`](variables.tf), outputs in [`outputs.tf`](outputs.tf).
