# The engine writes one JSON line per step to standard output: ids, counts and codes, never a
# message's content. The awslogs driver sends those lines to these log groups, encrypted under the
# given key. Nothing else is captured: no FireLens, no ECS Exec session log, no load balancer access
# log.

resource "aws_cloudwatch_log_group" "engine" {
  name              = "${var.log_group_prefix}/engine"
  retention_in_days = var.retention_days
  kms_key_id        = var.kms_key_arn
  tags              = var.tags
}

resource "aws_cloudwatch_log_group" "migrate" {
  name              = "${var.log_group_prefix}/migrate"
  retention_in_days = var.retention_days
  kms_key_id        = var.kms_key_arn
  tags              = var.tags
}
