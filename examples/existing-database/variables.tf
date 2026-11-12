variable "region" {
  description = "The AWS region to deploy into."
  type        = string
  default     = "us-east-1"
}

variable "vpc_id" {
  description = "The VPC to deploy into: the one your database is in, or one routed to it."
  type        = string
  default     = "vpc-0a1b2c3d4e5f60718"
}

variable "private_subnet_ids" {
  description = "Private subnets in two availability zones, with a route to a NAT gateway and to the database."
  type        = list(string)
  default     = ["subnet-0a1b2c3d4e5f60718", "subnet-0f1e2d3c4b5a60718"]
}

variable "allowed_cidr_blocks" {
  description = "The networks your MLLP sender connects from."
  type        = list(string)
  default     = ["10.20.0.0/16"]
}

variable "lab_cidr_blocks" {
  description = "The networks the lab's MLLP receiver is in, which the engine may reach on port 2576."
  type        = list(string)
  default     = ["10.40.0.0/24"]
}

variable "image" {
  description = "Your project's image, by digest."
  type        = string
  default     = "123456789012.dkr.ecr.us-east-1.amazonaws.com/pathways-existing-db@sha256:0000000000000000000000000000000000000000000000000000000000000000"
}

variable "master_key_secret_arn" {
  description = "The Secrets Manager secret holding the master key: 32 random bytes in base64."
  type        = string
  default     = "arn:aws:secretsmanager:us-east-1:123456789012:secret:pathways-existing-db/master-key-AbCdEf"
}

variable "database_url_secret_arn" {
  description = "The Secrets Manager secret holding your database's connection URL, postgres://<user>:<password>@<host>:5432/<database>, for a database and a user that are Pathways' alone."
  type        = string
  default     = "arn:aws:secretsmanager:us-east-1:123456789012:secret:pathways-existing-db/database-url-AbCdEf"
}

variable "database_security_group_id" {
  description = "The security group of your database. The module adds a rule to it that admits the engine on 5432."
  type        = string
  default     = "sg-0a1b2c3d4e5f60718"
}

variable "database_url_secret_kms_key_arns" {
  description = "The customer managed KMS key that encrypts database_url_secret_arn, if any, so the task execution role may decrypt it. Empty when the secret uses the AWS managed key."
  type        = list(string)
  default     = []
}
