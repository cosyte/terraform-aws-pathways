output "health_token_secret_arn" {
  description = "ARN of the Secrets Manager secret that holds the health endpoint's bearer token. ECS injects it into the engine and the collector as PATHWAYS_HEALTH_TOKEN; the execution role must be allowed to read it. The token itself is in no output, no plan and no state."
  value       = aws_secretsmanager_secret.health_token.arn
}

output "health_token_variable" {
  description = "The environment variable the engine's health endpoint and the collector read the token from."
  value       = local.token_variable
}

output "collector_config" {
  description = "The OpenTelemetry collector's configuration, in YAML: scrape /metrics at 127.0.0.1 on the health port, keep the four families, fold their labels away, and write them to the metrics log group. It names the token only as the variable it is read from."
  value       = local.collector_config
}

output "metrics_log_group_name" {
  description = "Name of the log group the collector writes the metrics to, as CloudWatch embedded metric format lines."
  value       = aws_cloudwatch_log_group.metrics.name
}

output "metrics_log_group_arn" {
  description = "ARN of the log group the collector writes the metrics to."
  value       = aws_cloudwatch_log_group.metrics.arn
}

output "namespace" {
  description = "The CloudWatch namespace of the metrics. Each carries the one dimension Deployment, the deployment's name."
  value       = local.namespace
}

output "alarm_arns" {
  description = "ARNs of the four alarms, by key: store_down, oldest_pending_age, refused_messages and settled_failed."
  value = {
    store_down         = aws_cloudwatch_metric_alarm.store_down.arn
    oldest_pending_age = aws_cloudwatch_metric_alarm.oldest_pending_age.arn
    refused_messages   = aws_cloudwatch_metric_alarm.refused_messages.arn
    settled_failed     = aws_cloudwatch_metric_alarm.settled_failed.arn
  }
}
