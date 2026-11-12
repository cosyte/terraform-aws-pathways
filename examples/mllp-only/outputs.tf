output "nlb_dns_name" {
  description = "Point both MLLP senders here, each at its own port: ADT on 2575, results on 2577."
  value       = module.pathways.nlb_dns_name
}

output "nlb_zone_id" {
  description = "The network load balancer's hosted zone, for a Route 53 alias record."
  value       = module.pathways.nlb_zone_id
}

output "cluster_name" {
  description = "The ECS cluster, for the migrate task and for aws ecs commands."
  value       = module.pathways.cluster_name
}

output "migrate_task_definition_arn" {
  description = "CI runs this with ECS RunTask before each deploy."
  value       = module.pathways.migrate_task_definition_arn
}

output "migrate_network_configuration" {
  description = "The --network-configuration for that RunTask."
  value       = module.pathways.migrate_network_configuration
}
