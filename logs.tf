# The engine writes one JSON line per step to standard output: ids, counts and codes, never a
# message's content. The awslogs driver sends those lines here, encrypted under the module's key.
# Nothing else is captured: no FireLens, no ECS Exec session log, no load balancer access log.

resource "aws_cloudwatch_log_group" "engine" {
  name              = "${local.log_group_prefix}/engine"
  retention_in_days = var.log_retention_days
  kms_key_id        = aws_kms_key.this.arn
  tags              = local.tags
}

resource "aws_cloudwatch_log_group" "migrate" {
  name              = "${local.log_group_prefix}/migrate"
  retention_in_days = var.log_retention_days
  kms_key_id        = aws_kms_key.this.arn
  tags              = local.tags
}
