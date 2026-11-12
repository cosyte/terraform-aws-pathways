# Plan-only tests of modules/bucket on its own, against a mocked aws provider. The policies are
# asserted on the policy documents' arguments; the mocked documents' JSON is a fixed empty policy.
# Every value is synthetic: the documentation account id 123456789012 and ids of zeros.

mock_provider "aws" {
  override_during = plan

  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }

  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
    }
  }

  mock_data "aws_region" {
    defaults = {
      region = "us-east-1"
    }
  }

  mock_resource "aws_s3_bucket" {
    defaults = {
      id     = "pathways-test-00000000000000000000000001"
      bucket = "pathways-test-00000000000000000000000001"
      arn    = "arn:aws:s3:::pathways-test-00000000000000000000000001"
    }
  }
}

variables {
  name           = "test"
  kms_key_arn    = "arn:aws:kms:us-east-1:123456789012:key/00000000-0000-0000-0000-000000000000"
  task_role_name = "pathways-test-task"
}

# ---------------------------------------------------------------------------
# The defaults
# ---------------------------------------------------------------------------

run "bucket_is_encrypted_under_the_key_with_a_bucket_key" {
  command = plan

  module {
    source = "./modules/bucket"
  }

  assert {
    condition = (
      one(aws_s3_bucket_server_side_encryption_configuration.this.rule).apply_server_side_encryption_by_default[0].sse_algorithm == "aws:kms"
      && one(aws_s3_bucket_server_side_encryption_configuration.this.rule).apply_server_side_encryption_by_default[0].kms_master_key_id == var.kms_key_arn
      && one(aws_s3_bucket_server_side_encryption_configuration.this.rule).bucket_key_enabled
    )
    error_message = "The bucket's objects are encrypted under the key given (SSE-KMS), with an S3 Bucket Key."
  }

  assert {
    condition     = aws_s3_bucket.this.bucket_prefix == "pathways-test-" && aws_s3_bucket.this.force_destroy == false
    error_message = "The bucket is named from the deployment, and a destroy never empties it on its own."
  }
}

run "bucket_and_log_bucket_are_private" {
  command = plan

  module {
    source = "./modules/bucket"
  }

  assert {
    condition = alltrue([
      for b in [aws_s3_bucket_public_access_block.this, aws_s3_bucket_public_access_block.access_logs] :
      b.block_public_acls && b.block_public_policy && b.ignore_public_acls && b.restrict_public_buckets
    ])
    error_message = "Both buckets block every kind of public access."
  }

  assert {
    condition = alltrue([
      for o in [aws_s3_bucket_ownership_controls.this, aws_s3_bucket_ownership_controls.access_logs] :
      one(o.rule).object_ownership == "BucketOwnerEnforced"
    ])
    error_message = "Both buckets turn ACLs off: the bucket owner owns every object."
  }
}

run "bucket_and_log_bucket_are_versioned" {
  command = plan

  module {
    source = "./modules/bucket"
  }

  assert {
    condition = (
      one(aws_s3_bucket_versioning.this.versioning_configuration).status == "Enabled"
      && one(aws_s3_bucket_versioning.access_logs.versioning_configuration).status == "Enabled"
    )
    error_message = "Both buckets are versioned."
  }
}

run "bucket_refuses_requests_without_tls" {
  command = plan

  module {
    source = "./modules/bucket"
  }

  assert {
    condition = anytrue([
      for s in data.aws_iam_policy_document.this.statement :
      s.effect == "Deny" && contains(s.actions, "s3:*")
      && toset(s.resources) == toset([aws_s3_bucket.this.arn, "${aws_s3_bucket.this.arn}/*"])
      && anytrue([for c in s.condition : c.test == "Bool" && c.variable == "aws:SecureTransport" && toset(c.values) == toset(["false"])])
    ])
    error_message = "The bucket's policy denies every request that does not use TLS."
  }

  assert {
    condition = anytrue([
      for s in data.aws_iam_policy_document.this.statement :
      s.effect == "Deny"
      && anytrue([for c in s.condition : c.test == "NumericLessThan" && c.variable == "s3:TlsVersion" && toset(c.values) == toset(["1.2"])])
    ])
    error_message = "The bucket's policy denies TLS older than 1.2."
  }

  assert {
    condition = anytrue([
      for s in data.aws_iam_policy_document.access_logs.statement :
      s.effect == "Deny"
      && anytrue([for c in s.condition : c.variable == "aws:SecureTransport" && toset(c.values) == toset(["false"])])
    ])
    error_message = "The log bucket's policy denies every request that does not use TLS."
  }

  assert {
    condition     = alltrue([for s in data.aws_iam_policy_document.this.statement : s.effect == "Deny"])
    error_message = "The bucket's policy only denies: it grants nobody anything."
  }
}

run "lifecycle_defaults_remove_noncurrent_versions_and_stale_uploads" {
  command = plan

  module {
    source = "./modules/bucket"
  }

  assert {
    condition = (
      length(aws_s3_bucket_lifecycle_configuration.this) == 1
      && [for r in aws_s3_bucket_lifecycle_configuration.this[0].rule : r.id] == ["default"]
      && one(aws_s3_bucket_lifecycle_configuration.this[0].rule[0].noncurrent_version_expiration).noncurrent_days == 30
      && one(aws_s3_bucket_lifecycle_configuration.this[0].rule[0].abort_incomplete_multipart_upload).days_after_initiation == 7
      && length(aws_s3_bucket_lifecycle_configuration.this[0].rule[0].expiration) == 0
    )
    error_message = "By default noncurrent versions go after 30 days, unfinished uploads after 7, and no current object expires."
  }
}

run "access_logs_go_to_the_log_bucket_under_sse_s3" {
  command = plan

  module {
    source = "./modules/bucket"
  }

  assert {
    condition = (
      aws_s3_bucket_logging.this.bucket == aws_s3_bucket.this.id
      && aws_s3_bucket_logging.this.target_bucket == aws_s3_bucket.access_logs.id
      && aws_s3_bucket_logging.this.target_prefix == "${aws_s3_bucket.this.id}/"
    )
    error_message = "The bucket's server access logs go to the log bucket, under the bucket's name."
  }

  assert {
    condition     = one(aws_s3_bucket_server_side_encryption_configuration.access_logs.rule).apply_server_side_encryption_by_default[0].sse_algorithm == "AES256"
    error_message = "The log bucket uses SSE-S3, the only default encryption server access logging delivers to."
  }

  assert {
    condition = anytrue([
      for s in data.aws_iam_policy_document.access_logs.statement :
      s.effect == "Allow" && toset(s.actions) == toset(["s3:PutObject"])
      && contains(flatten([for p in s.principals : tolist(p.identifiers)]), "logging.s3.amazonaws.com")
      && anytrue([for c in s.condition : c.variable == "aws:SourceArn" && toset(c.values) == toset([aws_s3_bucket.this.arn])])
      && anytrue([for c in s.condition : c.variable == "aws:SourceAccount" && toset(c.values) == toset(["123456789012"])])
    ])
    error_message = "Only the logging service, for this bucket in this account, may write to the log bucket."
  }

  assert {
    condition     = one(aws_s3_bucket_lifecycle_configuration.access_logs.rule).expiration[0].days == 365
    error_message = "The log bucket keeps logs for access_log_retention_days, 365 by default."
  }
}

run "task_role_reaches_this_bucket_and_key_alone" {
  command = plan

  module {
    source = "./modules/bucket"
  }

  assert {
    condition     = aws_iam_role_policy.task[0].role == "pathways-test-task"
    error_message = "The task role gets the bucket's policy."
  }

  assert {
    condition = anytrue([
      for s in data.aws_iam_policy_document.task.statement :
      toset(s.actions) == toset(["s3:ListBucket"]) && toset(s.resources) == toset([aws_s3_bucket.this.arn])
    ])
    error_message = "The task role may list this bucket."
  }

  assert {
    condition = anytrue([
      for s in data.aws_iam_policy_document.task.statement :
      toset(s.actions) == toset(["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]) && toset(s.resources) == toset(["${aws_s3_bucket.this.arn}/*"])
    ])
    error_message = "The task role may read, write and delete this bucket's objects, the calls a Pathways s3 block makes."
  }

  assert {
    condition = anytrue([
      for s in data.aws_iam_policy_document.task.statement :
      toset(s.actions) == toset(["kms:GenerateDataKey", "kms:Decrypt"]) && toset(s.resources) == toset([var.kms_key_arn])
      && anytrue([for c in s.condition : c.variable == "kms:ViaService" && toset(c.values) == toset(["s3.us-east-1.amazonaws.com"])])
    ])
    error_message = "The task role may use the key through S3 alone."
  }

  assert {
    condition = alltrue(flatten([
      for s in data.aws_iam_policy_document.task.statement : [
        for r in s.resources : startswith(r, aws_s3_bucket.this.arn) || r == var.kms_key_arn
      ]
    ]))
    error_message = "The task role's policy names this bucket and the key, and nothing else."
  }
}

# ---------------------------------------------------------------------------
# The caller's settings
# ---------------------------------------------------------------------------

run "lifecycle_rules_are_the_callers" {
  command = plan

  module {
    source = "./modules/bucket"
  }

  variables {
    lifecycle_rules = {
      outbox = { prefix = "outbox/", expiration_days = 90, noncurrent_version_expiration_days = 7 }
    }
    access_log_retention_days = 731
  }

  assert {
    condition = (
      [for r in aws_s3_bucket_lifecycle_configuration.this[0].rule : r.id] == ["outbox"]
      && one(aws_s3_bucket_lifecycle_configuration.this[0].rule[0].filter).prefix == "outbox/"
      && one(aws_s3_bucket_lifecycle_configuration.this[0].rule[0].expiration).days == 90
      && one(aws_s3_bucket_lifecycle_configuration.this[0].rule[0].noncurrent_version_expiration).noncurrent_days == 7
      && length(aws_s3_bucket_lifecycle_configuration.this[0].rule[0].abort_incomplete_multipart_upload) == 0
    )
    error_message = "lifecycle_rules replaces the default rule, with each action given and no other."
  }

  assert {
    condition     = one(aws_s3_bucket_lifecycle_configuration.access_logs.rule).expiration[0].days == 731
    error_message = "access_log_retention_days sets the log bucket's expiry."
  }
}

run "no_lifecycle_rules_no_lifecycle_configuration" {
  command = plan

  module {
    source = "./modules/bucket"
  }

  variables {
    lifecycle_rules = {}
  }

  assert {
    condition     = length(aws_s3_bucket_lifecycle_configuration.this) == 0
    error_message = "An empty lifecycle_rules sets no lifecycle configuration on the bucket."
  }
}

run "no_task_role_no_policy" {
  command = plan

  module {
    source = "./modules/bucket"
  }

  variables {
    task_role_name = null
  }

  assert {
    condition     = length(aws_iam_role_policy.task) == 0
    error_message = "With no task_role_name the module attaches nothing."
  }
}

# ---------------------------------------------------------------------------
# Inputs refused
# ---------------------------------------------------------------------------

run "key_alias_is_refused" {
  command = plan

  module {
    source = "./modules/bucket"
  }

  variables {
    kms_key_arn = "alias/pathways-test"
  }

  expect_failures = [var.kms_key_arn]
}

run "lifecycle_rule_of_zero_days_is_refused" {
  command = plan

  module {
    source = "./modules/bucket"
  }

  variables {
    lifecycle_rules = {
      inbox = { expiration_days = 0 }
    }
  }

  expect_failures = [var.lifecycle_rules]
}

run "lifecycle_rule_without_an_action_is_refused" {
  command = plan

  module {
    source = "./modules/bucket"
  }

  variables {
    lifecycle_rules = {
      inbox = { prefix = "inbox/" }
    }
  }

  expect_failures = [var.lifecycle_rules]
}

run "access_log_retention_of_zero_is_refused" {
  command = plan

  module {
    source = "./modules/bucket"
  }

  variables {
    access_log_retention_days = 0
  }

  expect_failures = [var.access_log_retention_days]
}
