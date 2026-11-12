output "sftp_endpoint" {
  description = "Where the partners connect over SFTP, on port 22, through the VPC endpoint."
  value       = module.pathways.sftp_endpoint
}

output "sftp_vpc_endpoint_id" {
  description = "The SFTP server's VPC endpoint: its network interfaces hold the private addresses partners reach."
  value       = module.pathways.sftp_vpc_endpoint_id
}

output "bucket_name" {
  description = "The bucket behind SFTP, which the engine reads as PATHWAYS_BUCKET."
  value       = module.pathways.bucket_name
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
