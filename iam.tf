# Two roles. The execution role is what ECS itself uses to start a task: pull the image, read the
# secrets it injects, and write the logs. The task role is what the engine's own code runs as; it
# starts with no permissions, and the caller attaches what an extension needs (its name is an
# output).

locals {
  # A Secrets Manager reference may carry :json-key:version-stage:version-id after the secret's own
  # ARN; IAM names the secret by its ARN alone, the first seven fields.
  caller_secret_arns = distinct([
    for v in values(var.secrets) : join(":", slice(split(":", v), 0, 7))
    if can(regex("^arn:aws[a-z-]*:secretsmanager:", v))
  ])
  caller_parameter_arns = distinct([
    for v in values(var.secrets) : v if can(regex("^arn:aws[a-z-]*:ssm:", v))
  ])
  registry_secret_arns = var.repository_credentials_secret_arn == null ? [] : [var.repository_credentials_secret_arn]

  # An image in ECR: <account>.dkr.ecr.<region>.amazonaws.com[.cn]/<repository>[:tag]@sha256:<digest>.
  # The migrate image is usually the same repository at a newer digest, but need not be.
  ecr_pattern = "^([0-9]{12})\\.dkr\\.ecr\\.([a-z0-9-]+)\\.amazonaws\\.com(?:\\.cn)?/([^@:]+)"
  ecr_matches = [
    for image in compact([var.image, var.migrate_image]) : regex(local.ecr_pattern, image)
    if can(regex(local.ecr_pattern, image))
  ]
  ecr_repository_arns = distinct([
    for m in local.ecr_matches : "arn:${local.partition}:ecr:${m[1]}:${m[0]}:repository/${m[2]}"
  ])
}

data "aws_iam_policy_document" "ecs_tasks_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }

    # Only ECS acting for this account may assume the roles.
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.account_id]
    }
  }
}

resource "aws_iam_role" "execution" {
  name               = "pathways-${var.name}-execution"
  description        = "Pathways ${var.name}: ECS starts the engine and migrate tasks with it"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume.json
  tags               = local.tags
}

data "aws_iam_policy_document" "execution" {
  # ECR is read only when an image is in ECR, and then only its own repository. The token call
  # names no resource, so IAM takes it on "*" alone.
  dynamic "statement" {
    for_each = length(local.ecr_repository_arns) > 0 ? [1] : []
    content {
      sid       = "EcrToken"
      effect    = "Allow"
      actions   = ["ecr:GetAuthorizationToken"]
      resources = ["*"]
    }
  }

  dynamic "statement" {
    for_each = length(local.ecr_repository_arns) > 0 ? [local.ecr_repository_arns] : []
    content {
      sid    = "PullImage"
      effect = "Allow"
      actions = [
        "ecr:BatchCheckLayerAvailability",
        "ecr:BatchGetImage",
        "ecr:GetDownloadUrlForLayer",
      ]
      resources = statement.value
    }
  }

  statement {
    sid     = "WriteLogs"
    effect  = "Allow"
    actions = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = [
      "${aws_cloudwatch_log_group.engine.arn}:*",
      "${aws_cloudwatch_log_group.migrate.arn}:*",
    ]
  }

  statement {
    sid       = "ReadSecrets"
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = concat([aws_secretsmanager_secret.database_url.arn], local.caller_secret_arns, local.registry_secret_arns)
  }

  dynamic "statement" {
    for_each = length(local.caller_parameter_arns) > 0 ? [1] : []
    content {
      sid       = "ReadParameters"
      effect    = "Allow"
      actions   = ["ssm:GetParameters"]
      resources = local.caller_parameter_arns
    }
  }

  statement {
    sid       = "DecryptSecrets"
    effect    = "Allow"
    actions   = ["kms:Decrypt"]
    resources = concat([aws_kms_key.this.arn], var.secrets_kms_key_arns)
  }
}

resource "aws_iam_role_policy" "execution" {
  name   = "start-tasks"
  role   = aws_iam_role.execution.id
  policy = data.aws_iam_policy_document.execution.json
}

resource "aws_iam_role" "task" {
  name               = "pathways-${var.name}-task"
  description        = "Pathways ${var.name}: the engine and migrate tasks run as it; no permissions until the caller attaches some"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume.json
  tags               = local.tags
}
