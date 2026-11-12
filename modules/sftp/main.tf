# An AWS Transfer Family SFTP server for partners who drop and pick up files, in front of the
# bucket a Pathways file source reads and a file destination writes.
#
#   the endpoint   a VPC endpoint in the given subnets, with no Elastic IP, so it is reachable only
#                  from inside the VPC and what is connected to it, and only from
#                  allowed_cidr_blocks, on port 22
#   the users      service managed, each with the SSH public keys given, locked to a home prefix in
#                  the bucket by a logical home directory and by a role that reaches that prefix
#                  alone
#   the logs       structured JSON logs to a CloudWatch log group encrypted under the given key

data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

data "aws_region" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  partition  = data.aws_partition.current.partition
  region     = data.aws_region.current.region

  bucket_arn = "arn:${local.partition}:s3:::${var.bucket_name}"

  # Each (user, key) pair, keyed by the user's name and the key's place in its list.
  ssh_keys = merge({}, [
    for u, user in var.users : {
      for i, key in user.public_keys : "${u}-${i}" => { user = u, body = key }
    }
  ]...)
}

# ---------------------------------------------------------------------------
# Who may connect
# ---------------------------------------------------------------------------

resource "aws_security_group" "this" {
  name        = "pathways-${var.name}-sftp"
  description = "Pathways ${var.name}: the SFTP endpoint, reachable from the allowed networks only"
  vpc_id      = var.vpc_id
  tags        = var.tags
}

resource "aws_vpc_security_group_ingress_rule" "this" {
  for_each = toset(var.allowed_cidr_blocks)

  security_group_id = aws_security_group.this.id
  description       = "SFTP from ${each.value}"
  cidr_ipv4         = each.value
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  tags              = var.tags
}

# ---------------------------------------------------------------------------
# Logs
# ---------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "this" {
  name              = var.log_group_name
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn
  tags              = var.tags
}

data "aws_iam_policy_document" "transfer_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["transfer.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.account_id]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:${local.partition}:transfer:${local.region}:${local.account_id}:*"]
    }
  }
}

resource "aws_iam_role" "logging" {
  name               = "pathways-${var.name}-sftp-logging"
  description        = "Pathways ${var.name}: the SFTP server writes its logs with it"
  assume_role_policy = data.aws_iam_policy_document.transfer_assume.json
  tags               = var.tags
}

data "aws_iam_policy_document" "logging" {
  statement {
    sid    = "WriteLogs"
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:DescribeLogStreams",
      "logs:PutLogEvents",
    ]
    resources = ["${aws_cloudwatch_log_group.this.arn}:*"]
  }
}

resource "aws_iam_role_policy" "logging" {
  name   = "write-logs"
  role   = aws_iam_role.logging.id
  policy = data.aws_iam_policy_document.logging.json
}

# ---------------------------------------------------------------------------
# The server
# ---------------------------------------------------------------------------

resource "aws_transfer_server" "this" {
  endpoint_type          = "VPC"
  protocols              = ["SFTP"]
  identity_provider_type = "SERVICE_MANAGED"
  domain                 = "S3"
  security_policy_name   = var.security_policy_name

  # No address_allocation_ids: without Elastic IPs the endpoint is internal to the VPC.
  endpoint_details {
    vpc_id             = var.vpc_id
    subnet_ids         = var.subnet_ids
    security_group_ids = [aws_security_group.this.id]
  }

  logging_role                = aws_iam_role.logging.arn
  structured_log_destinations = ["${aws_cloudwatch_log_group.this.arn}:*"]

  tags = merge(var.tags, {
    Name = "pathways-${var.name}"
  })

  depends_on = [aws_iam_role_policy.logging]
}

# ---------------------------------------------------------------------------
# The users
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "user_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["transfer.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.account_id]
    }

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [aws_transfer_server.this.arn]
    }
  }
}

resource "aws_iam_role" "user" {
  for_each = var.users

  name               = "pathways-${var.name}-sftp-${each.key}"
  description        = "Pathways ${var.name}: SFTP user ${each.key}, under ${each.value.home_prefix}/ in the bucket"
  assume_role_policy = data.aws_iam_policy_document.user_assume.json
  tags               = var.tags
}

data "aws_iam_policy_document" "user" {
  for_each = var.users

  # Listing is allowed under the user's own prefix alone.
  statement {
    sid       = "ListHomePrefix"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [local.bucket_arn]

    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = [each.value.home_prefix, "${each.value.home_prefix}/*"]
    }
  }

  statement {
    sid       = "BucketLocation"
    effect    = "Allow"
    actions   = ["s3:GetBucketLocation"]
    resources = [local.bucket_arn]
  }

  statement {
    sid    = "ReadWriteHomePrefix"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
    ]
    resources = ["${local.bucket_arn}/${each.value.home_prefix}/*"]
  }

  statement {
    sid       = "UseTheBucketKey"
    effect    = "Allow"
    actions   = ["kms:GenerateDataKey", "kms:Decrypt"]
    resources = [var.kms_key_arn]

    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["s3.${local.region}.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "user" {
  for_each = var.users

  name   = "home-prefix"
  role   = aws_iam_role.user[each.key].id
  policy = data.aws_iam_policy_document.user[each.key].json
}

resource "aws_transfer_user" "this" {
  for_each = var.users

  server_id = aws_transfer_server.this.id
  user_name = each.key
  role      = aws_iam_role.user[each.key].arn

  # A logical home directory: the user sees / and nothing above it, and / is their prefix.
  home_directory_type = "LOGICAL"
  home_directory_mappings {
    entry  = "/"
    target = "/${var.bucket_name}/${each.value.home_prefix}"
  }

  tags = var.tags
}

resource "aws_transfer_ssh_key" "this" {
  for_each = local.ssh_keys

  server_id = aws_transfer_server.this.id
  user_name = aws_transfer_user.this[each.value.user].user_name
  body      = each.value.body
}
