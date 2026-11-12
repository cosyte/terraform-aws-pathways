output "execution_role_arn" {
  description = "ARN of the role ECS starts the tasks with."
  value       = aws_iam_role.execution.arn
}

output "execution_role_name" {
  description = "Name of the role ECS starts the tasks with."
  value       = aws_iam_role.execution.name
}

output "task_role_arn" {
  description = "ARN of the role the tasks run as."
  value       = aws_iam_role.task.arn
}

output "task_role_name" {
  description = "Name of the role the tasks run as. It has no permissions: attach a policy for an extension that calls AWS."
  value       = aws_iam_role.task.name
}
