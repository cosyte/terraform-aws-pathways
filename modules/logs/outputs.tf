output "engine_log_group_name" {
  description = "Name of the engine's CloudWatch log group."
  value       = aws_cloudwatch_log_group.engine.name
}

output "engine_log_group_arn" {
  description = "ARN of the engine's CloudWatch log group."
  value       = aws_cloudwatch_log_group.engine.arn
}

output "migrate_log_group_name" {
  description = "Name of the migrate task's CloudWatch log group."
  value       = aws_cloudwatch_log_group.migrate.name
}

output "migrate_log_group_arn" {
  description = "ARN of the migrate task's CloudWatch log group."
  value       = aws_cloudwatch_log_group.migrate.arn
}
