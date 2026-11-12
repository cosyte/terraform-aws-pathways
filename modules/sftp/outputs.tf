output "server_id" {
  description = "ID of the Transfer Family server."
  value       = aws_transfer_server.this.id
}

output "server_arn" {
  description = "ARN of the Transfer Family server."
  value       = aws_transfer_server.this.arn
}

output "endpoint" {
  description = "The server's own hostname, s-<id>.server.transfer.<region>.amazonaws.com."
  value       = aws_transfer_server.this.endpoint
}

output "vpc_endpoint_id" {
  description = "ID of the server's VPC endpoint. Its DNS names and private addresses are where SFTP clients inside the VPC connect."
  value       = try(aws_transfer_server.this.endpoint_details[0].vpc_endpoint_id, null)
}

output "security_group_id" {
  description = "ID of the endpoint's security group, which admits allowed_cidr_blocks on port 22 only."
  value       = aws_security_group.this.id
}

output "log_group_name" {
  description = "Name of the server's CloudWatch log group."
  value       = aws_cloudwatch_log_group.this.name
}

output "user_role_arns" {
  description = "ARN of each user's role, by user name: it reaches the user's home prefix alone."
  value       = { for u, r in aws_iam_role.user : u => r.arn }
}
