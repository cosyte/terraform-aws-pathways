# One customer managed key for everything the module stores: the database's storage (unless the
# caller gives database_kms_key_arn), the secret that holds its connection URL, and both log groups.
# It rotates every year.

resource "aws_kms_key" "this" {
  description             = "Pathways ${var.name}: the database, its secret and the logs"
  enable_key_rotation     = true
  deletion_window_in_days = var.kms_key_deletion_window_days
  policy                  = data.aws_iam_policy_document.kms.json
  tags                    = local.tags
}

resource "aws_kms_alias" "this" {
  name          = "alias/pathways-${var.name}"
  target_key_id = aws_kms_key.this.key_id
}

data "aws_iam_policy_document" "kms" {
  # The account administers the key through IAM, as a key AWS creates for you does. RDS and Secrets
  # Manager use it on behalf of the roles the account grants it to.
  statement {
    sid       = "AccountAdministers"
    effect    = "Allow"
    actions   = ["kms:*"]
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = ["arn:${local.partition}:iam::${local.account_id}:root"]
    }
  }

  # CloudWatch Logs encrypts this deployment's log groups with it, and no other.
  statement {
    sid    = "CloudWatchLogsUsesForThisDeployment"
    effect = "Allow"
    actions = [
      "kms:Encrypt*",
      "kms:Decrypt*",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:Describe*",
    ]
    resources = ["*"]

    principals {
      type        = "Service"
      identifiers = ["logs.${local.region}.amazonaws.com"]
    }

    condition {
      test     = "ArnLike"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values   = ["arn:${local.partition}:logs:${local.region}:${local.account_id}:log-group:${local.log_group_prefix}/*"]
    }
  }
}
