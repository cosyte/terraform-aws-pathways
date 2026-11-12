output "address" {
  description = "Hostname of the PostgreSQL instance. Connections must use TLS, verified against the RDS certificate authority."
  value       = aws_db_instance.this.address
}

output "port" {
  description = "Port of the PostgreSQL instance."
  value       = aws_db_instance.this.port
}

output "instance_arn" {
  description = "ARN of the RDS instance."
  value       = aws_db_instance.this.arn
}

output "storage_kms_key_arn" {
  description = "ARN of the KMS key that encrypts the database's storage, its backups and its final snapshot."
  value       = local.storage_kms_key_arn
}

output "url_secret_arn" {
  description = "ARN of the Secrets Manager secret holding the connection URL, password inside."
  value       = aws_secretsmanager_secret.url.arn
}
