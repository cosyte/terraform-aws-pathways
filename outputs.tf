output "cluster_arn" {
  description = "ARN of the ECS cluster."
  value       = module.ecs.cluster_arn
}

output "cluster_name" {
  description = "Name of the ECS cluster."
  value       = module.ecs.cluster_name
}

output "service_name" {
  description = "Name of the ECS service that runs the engine."
  value       = module.ecs.service_name
}

output "engine_task_definition_arn" {
  description = "ARN of the engine's task definition, at its current revision."
  value       = module.ecs.engine_task_definition_arn
}

output "migrate_task_definition_arn" {
  description = "ARN of the migrate task definition, at its current revision. CI runs it with ECS RunTask, on the image it is about to deploy, and waits for it to exit 0 before it applies that image to the service."
  value       = module.ecs.migrate_task_definition_arn
}

output "migrate_network_configuration" {
  description = "The network configuration for an ECS RunTask of the migrate task definition, as the JSON aws ecs run-task --network-configuration takes: the private subnets and the engine's security group, which the database admits."
  value = jsonencode({
    awsvpcConfiguration = {
      subnets        = var.private_subnet_ids
      securityGroups = [module.security_groups.engine_security_group_id]
      assignPublicIp = "DISABLED"
    }
  })
}

output "engine_security_group_id" {
  description = "ID of the engine's security group. The database admits it; add rules to it, or to a destination's own group, for anything else the engine reaches."
  value       = module.security_groups.engine_security_group_id
}

output "task_role_name" {
  description = "Name of the role the engine and migrate tasks run as. It has no permissions: attach a policy for an extension that calls AWS."
  value       = module.iam.task_role_name
}

output "task_role_arn" {
  description = "ARN of the role the engine and migrate tasks run as."
  value       = module.iam.task_role_arn
}

output "execution_role_arn" {
  description = "ARN of the role ECS starts the tasks with. A CI role that runs the migrate task needs iam:PassRole on it and on task_role_arn."
  value       = module.iam.execution_role_arn
}

output "kms_key_arn" {
  description = "ARN of the customer managed KMS key that encrypts the database, its secret and the logs."
  value       = module.kms.key_arn
}

output "database_address" {
  description = "Hostname of the PostgreSQL instance. Connections must use TLS, verified against the RDS certificate authority."
  value       = module.database.address
}

output "database_url_secret_arn" {
  description = "ARN of the Secrets Manager secret holding the database's connection URL, which ECS injects as PATHWAYS_DATABASE_URL."
  value       = module.database.url_secret_arn
}

output "engine_log_group_name" {
  description = "Name of the engine's CloudWatch log group."
  value       = module.logs.engine_log_group_name
}

output "migrate_log_group_name" {
  description = "Name of the migrate task's CloudWatch log group."
  value       = module.logs.migrate_log_group_name
}

output "nlb_dns_name" {
  description = "DNS name of the network load balancer for the MLLP sources, or null when there is none."
  value       = module.load_balancers.nlb_dns_name
}

output "nlb_zone_id" {
  description = "Hosted zone ID of the network load balancer, for a Route 53 alias record, or null."
  value       = module.load_balancers.nlb_zone_id
}

output "alb_dns_name" {
  description = "DNS name of the application load balancer for the HTTP sources, or null when there is none."
  value       = module.load_balancers.alb_dns_name
}

output "alb_zone_id" {
  description = "Hosted zone ID of the application load balancer, for a Route 53 alias record, or null."
  value       = module.load_balancers.alb_zone_id
}
