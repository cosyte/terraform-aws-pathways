output "nlb_dns_name" {
  description = "Point your MLLP senders here, or at a DNS name aliased to it."
  value       = module.pathways.nlb_dns_name
}

output "alb_dns_name" {
  description = "Point your HTTP senders here, or at a DNS name aliased to it."
  value       = module.pathways.alb_dns_name
}

output "migrate_task_definition_arn" {
  description = "CI runs this with ECS RunTask before each deploy."
  value       = module.pathways.migrate_task_definition_arn
}

output "migrate_network_configuration" {
  description = "The --network-configuration for that RunTask."
  value       = module.pathways.migrate_network_configuration
}
