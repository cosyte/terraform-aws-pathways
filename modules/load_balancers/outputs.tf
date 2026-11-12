output "nlb_arn" {
  description = "ARN of the network load balancer, or null when there is none."
  value       = local.create_nlb ? aws_lb.nlb[0].arn : null
}

output "nlb_dns_name" {
  description = "DNS name of the network load balancer for the MLLP sources, or null when there is none."
  value       = local.create_nlb ? aws_lb.nlb[0].dns_name : null
}

output "nlb_zone_id" {
  description = "Hosted zone ID of the network load balancer, for a Route 53 alias record, or null."
  value       = local.create_nlb ? aws_lb.nlb[0].zone_id : null
}

output "alb_arn" {
  description = "ARN of the application load balancer, or null when there is none."
  value       = local.create_alb ? aws_lb.alb[0].arn : null
}

output "alb_dns_name" {
  description = "DNS name of the application load balancer for the HTTP sources, or null when there is none."
  value       = local.create_alb ? aws_lb.alb[0].dns_name : null
}

output "alb_zone_id" {
  description = "Hosted zone ID of the application load balancer, for a Route 53 alias record, or null."
  value       = local.create_alb ? aws_lb.alb[0].zone_id : null
}

# ECS attaches a service to a target group only once a listener has attached the group to its load
# balancer, so these wait for the listeners: a service that reads them is created after those.

output "mllp_target_group_arns" {
  description = "ARN of each MLLP source's target group, by source name. Read after the listeners exist."
  value       = { for k, tg in aws_lb_target_group.mllp : k => tg.arn }
  depends_on  = [aws_lb_listener.mllp]
}

output "http_target_group_arns" {
  description = "ARN of each HTTP source's target group, by source name. Read after the listeners exist."
  value       = { for k, tg in aws_lb_target_group.http : k => tg.arn }
  depends_on  = [aws_lb_listener.http]
}
