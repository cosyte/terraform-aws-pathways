output "engine_security_group_id" {
  description = "ID of the engine's security group. The database admits it."
  value       = aws_security_group.engine.id
}

output "database_security_group_id" {
  description = "ID of the database's security group, which admits the engine's: this module's own, or database_security_group_id when that is given."
  value       = local.database_group_id
}

output "nlb_security_group_id" {
  description = "ID of the network load balancer's security group, or null when there is no MLLP source."
  value       = local.create_nlb ? aws_security_group.nlb[0].id : null
}

output "alb_security_group_id" {
  description = "ID of the application load balancer's security group, or null when there is no HTTP source."
  value       = local.create_alb ? aws_security_group.alb[0].id : null
}
