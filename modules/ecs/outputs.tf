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

output "metrics_collector_container" {
  description = "The metrics collector's container definition, as the engine's task definition gives it to ECS, or null with no metrics_collector. The health token appears as the ARN ECS reads it from, never as its value."
  value       = local.metrics_collector_container
}

output "engine_task_container_definitions" {
  description = "The engine task definition's container definitions, the JSON ECS gets: the engine alone, or the engine and the metrics collector."
  value       = local.engine_task_container_definitions
}
