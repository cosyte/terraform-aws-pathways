output "cluster_arn" {
  description = "ARN of the ECS cluster."
  value       = aws_ecs_cluster.this.arn
}

output "cluster_name" {
  description = "Name of the ECS cluster."
  value       = aws_ecs_cluster.this.name
}

output "service_name" {
  description = "Name of the ECS service that runs the engine."
  value       = aws_ecs_service.engine.name
}

output "engine_task_definition_arn" {
  description = "ARN of the engine's task definition, at its current revision."
  value       = aws_ecs_task_definition.engine.arn
}

output "migrate_task_definition_arn" {
  description = "ARN of the migrate task definition, at its current revision. CI runs it with ECS RunTask, on the image it is about to deploy, and waits for it to exit 0 before it applies that image to the service."
  value       = aws_ecs_task_definition.migrate.arn
}

output "migrate_network_configuration" {
  description = "The network configuration for an ECS RunTask of the migrate task definition, as the JSON aws ecs run-task --network-configuration takes: the private subnets and the engine's security group, which the database admits."
  value = jsonencode({
    awsvpcConfiguration = {
      subnets        = var.private_subnet_ids
      securityGroups = [aws_security_group.engine.id]
      assignPublicIp = "DISABLED"
    }
  })
}

output "engine_security_group_id" {
  description = "ID of the engine's security group. The database admits it; add rules to it, or to a destination's own group, for anything else the engine reaches."
  value       = aws_security_group.engine.id
}

output "task_role_name" {
  description = "Name of the role the engine and migrate tasks run as. It has no permissions: attach a policy for an extension that calls AWS."
  value       = aws_iam_role.task.name
}

output "task_role_arn" {
  description = "ARN of the role the engine and migrate tasks run as."
  value       = aws_iam_role.task.arn
}

output "execution_role_arn" {
  description = "ARN of the role ECS starts the tasks with. A CI role that runs the migrate task needs iam:PassRole on it and on task_role_arn."
  value       = aws_iam_role.execution.arn
}

output "kms_key_arn" {
  description = "ARN of the customer managed KMS key that encrypts the database, its secret and the logs."
  value       = aws_kms_key.this.arn
}

output "database_address" {
  description = "Hostname of the PostgreSQL instance. Connections must use TLS, verified against the RDS certificate authority."
  value       = aws_db_instance.this.address
}

output "database_url_secret_arn" {
  description = "ARN of the Secrets Manager secret holding the database's connection URL, which ECS injects as PATHWAYS_DATABASE_URL."
  value       = aws_secretsmanager_secret.database_url.arn
}

output "engine_log_group_name" {
  description = "Name of the engine's CloudWatch log group."
  value       = aws_cloudwatch_log_group.engine.name
}

output "migrate_log_group_name" {
  description = "Name of the migrate task's CloudWatch log group."
  value       = aws_cloudwatch_log_group.migrate.name
}

output "nlb_dns_name" {
  description = "DNS name of the network load balancer for the MLLP sources, or null when there is none."
  value       = local.create_nlb ? aws_lb.nlb[0].dns_name : null
}

output "nlb_zone_id" {
  description = "Hosted zone ID of the network load balancer, for a Route 53 alias record, or null."
  value       = local.create_nlb ? aws_lb.nlb[0].zone_id : null
}

output "alb_dns_name" {
  description = "DNS name of the application load balancer for the HTTP sources, or null when there is none."
  value       = local.create_alb ? aws_lb.alb[0].dns_name : null
}

output "alb_zone_id" {
  description = "Hosted zone ID of the application load balancer, for a Route 53 alias record, or null."
  value       = local.create_alb ? aws_lb.alb[0].zone_id : null
}
