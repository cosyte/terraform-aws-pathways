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
  description = "ARN of the migrate task definition, at its current revision."
  value       = aws_ecs_task_definition.migrate.arn
}

output "engine_container" {
  description = "The engine's container definition, as the task definition gives it to ECS. Secrets appear as the ARNs ECS reads them from, never as values."
  value       = local.engine_container
}

output "migrate_container" {
  description = "The migrate task's container definition, as the task definition gives it to ECS."
  value       = local.migrate_container
}
