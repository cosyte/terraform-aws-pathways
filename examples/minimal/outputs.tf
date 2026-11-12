output "nlb_dns_name" {
  description = "Point your MLLP sender here, or at a DNS name aliased to it."
  value       = module.pathways.nlb_dns_name
}

output "cluster_name" {
  description = "The ECS cluster, for the migrate task and for aws ecs commands."
  value       = module.pathways.cluster_name
}

output "service_name" {
  description = "The ECS service that runs the engine."
  value       = module.pathways.service_name
}

output "engine_log_group_name" {
  description = "Where the engine's log lines go."
  value       = module.pathways.engine_log_group_name
}

output "migrate_task_definition_arn" {
  description = "CI runs this with ECS RunTask before each deploy."
  value       = module.pathways.migrate_task_definition_arn
}

output "migrate_network_configuration" {
  description = "The --network-configuration for that RunTask."
  value       = module.pathways.migrate_network_configuration
}
