variable "region" {
  description = "The AWS region to deploy into."
  type        = string
  default     = "us-east-1"
}

variable "vpc_id" {
  description = "The VPC to deploy into."
  type        = string
  default     = "vpc-0a1b2c3d4e5f60718"
}

variable "private_subnet_ids" {
  description = "Private subnets in two availability zones, with a route to a NAT gateway."
  type        = list(string)
  default     = ["subnet-0a1b2c3d4e5f60718", "subnet-0f1e2d3c4b5a60718"]
}

variable "allowed_cidr_blocks" {
  description = "The networks the ordering system sends from."
  type        = list(string)
  default     = ["10.20.0.0/16"]
}

variable "alb_certificate_arn" {
  description = "The ACM certificate the application load balancer presents, for the name your senders use."
  type        = string
  default     = "arn:aws:acm:us-east-1:123456789012:certificate/00000000-0000-0000-0000-000000000000"
}

variable "image" {
  description = "Your project's image, by digest."
  type        = string
  default     = "123456789012.dkr.ecr.us-east-1.amazonaws.com/pathways-http-only@sha256:0000000000000000000000000000000000000000000000000000000000000000"
}

variable "master_key_secret_arn" {
  description = "The Secrets Manager secret holding the master key: 32 random bytes in base64."
  type        = string
  default     = "arn:aws:secretsmanager:us-east-1:123456789012:secret:pathways-http-only/master-key-AbCdEf"
}

variable "orders_token_secret_arn" {
  description = "The Secrets Manager secret holding the bearer token the ordering system sends."
  type        = string
  default     = "arn:aws:secretsmanager:us-east-1:123456789012:secret:pathways-http-only/orders-token-AbCdEf"
}
