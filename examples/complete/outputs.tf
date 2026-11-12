output "nlb_dns_name" {
  description = "Point your MLLP senders here, or at a DNS name aliased to it."
  value       = module.pathways.nlb_dns_name
}

output "bucket_name" {
  description = "The bucket the channel writes to, which the engine reads as PATHWAYS_BUCKET."
  value       = module.pathways.bucket_name
}

output "sftp_endpoint" {
  description = "The SFTP server's hostname, for the lab."
  value       = module.pathways.sftp_endpoint
}

output "sftp_vpc_endpoint_id" {
  description = "The SFTP server's VPC endpoint, whose DNS names and private addresses the lab connects to from inside the VPC or over its VPN."
  value       = module.pathways.sftp_vpc_endpoint_id
}

output "migrate_task_definition_arn" {
  description = "CI runs this with ECS RunTask before each deploy."
  value       = module.pathways.migrate_task_definition_arn
}

output "migrate_network_configuration" {
  description = "The --network-configuration for that RunTask."
  value       = module.pathways.migrate_network_configuration
}
