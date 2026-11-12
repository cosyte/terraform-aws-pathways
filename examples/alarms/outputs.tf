output "nlb_dns_name" {
  description = "Point your MLLP sender here, or at a DNS name aliased to it."
  value       = module.pathways.nlb_dns_name
}

output "cluster_name" {
  description = "The ECS cluster, for the migrate task and for aws ecs commands."
  value       = module.pathways.cluster_name
}

output "service_name" {
  description = "The ECS service that runs the engine and the metrics collector."
  value       = module.pathways.service_name
}

output "alarm_arns" {
  description = "The four alarms, by key."
  value       = module.pathways.alarm_arns
}

output "metrics_log_group_name" {
  description = "Where the collector writes the four metrics."
  value       = module.pathways.metrics_log_group_name
}

output "health_token_secret_arn" {
  description = "The secret holding the health endpoint's token, by ARN. Read the token from Secrets Manager when you need to call the endpoint yourself."
  value       = module.pathways.health_token_secret_arn
}

output "migrate_task_definition_arn" {
  description = "CI runs this with ECS RunTask before each deploy."
  value       = module.pathways.migrate_task_definition_arn
}

output "migrate_network_configuration" {
  description = "The --network-configuration for that RunTask."
  value       = module.pathways.migrate_network_configuration
}
