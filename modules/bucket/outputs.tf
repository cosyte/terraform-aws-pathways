output "bucket_name" {
  description = "Name of the bucket, for the bucket key of a Pathways s3 block."
  value       = aws_s3_bucket.this.id
}

output "bucket_arn" {
  description = "ARN of the bucket."
  value       = aws_s3_bucket.this.arn
}

output "access_logs_bucket_name" {
  description = "Name of the bucket that receives the bucket's server access logs, under the prefix <bucket name>/."
  value       = aws_s3_bucket.access_logs.id
}

output "task_policy_json" {
  description = "The policy the task role gets: list the bucket, read, write and delete its objects, and use the key for them through S3. Attach it to another role that needs the same access."
  value       = data.aws_iam_policy_document.task.json
}

output "task_policy_role_name" {
  description = "Name of the role the module gave the bucket's policy to, or null when task_role_name is null."
  value       = try(aws_iam_role_policy.task[0].role, null)
}
