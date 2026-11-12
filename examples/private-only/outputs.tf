output "nlb_dns_name" {
  description = "Point your MLLP sender here: it resolves to private addresses only."
  value       = module.pathways.nlb_dns_name
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
  description = "The --network-configuration for that RunTask: no public IP, so it needs the endpoints too."
  value       = module.pathways.migrate_network_configuration
}

output "vpc_endpoint_ids" {
  description = "The interface endpoints, by service, and the S3 gateway endpoint."
  value       = merge({ for k, e in aws_vpc_endpoint.interface : k => e.id }, { s3 = aws_vpc_endpoint.s3.id })
}
