output "alb_dns_name" {
  description = "Point a DNS name on your certificate at this (an alias record), and send to https://<that name>:8443/orders."
  value       = module.pathways.alb_dns_name
}

output "alb_zone_id" {
  description = "The application load balancer's hosted zone, for a Route 53 alias record."
  value       = module.pathways.alb_zone_id
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
