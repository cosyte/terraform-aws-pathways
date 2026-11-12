output "nlb_dns_name" {
  description = "Point your MLLP sender here, or at a DNS name aliased to it."
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
  description = "The --network-configuration for that RunTask."
  value       = module.pathways.migrate_network_configuration
}

output "database_instance_arn" {
  description = "The database whose backups are replicated."
  value       = module.pathways.database_instance_arn
}

output "replicated_backups_arn" {
  description = "The replicated automated backups in the backup region: the --source-db-instance-automated-backups-arn of a restore."
  value       = aws_db_instance_automated_backups_replication.this.id
}

output "backup_kms_key_arn" {
  description = "The key in the backup region that encrypts the replicated backups, and the restored instance."
  value       = aws_kms_key.backup.arn
}
