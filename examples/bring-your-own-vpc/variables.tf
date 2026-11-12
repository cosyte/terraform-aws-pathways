variable "region" {
  description = "The AWS region to deploy into."
  type        = string
  default     = "us-east-1"
}

variable "vpc_name" {
  description = "The Name tag of your VPC."
  type        = string
  default     = "integration-vpc"
}

variable "app_subnet_tier" {
  description = "The Tier tag of the private subnets the engine runs in, with a route to a NAT gateway, in at least two availability zones."
  type        = string
  default     = "app"
}

variable "data_subnet_tier" {
  description = "The Tier tag of the subnets the database runs in, in at least two availability zones."
  type        = string
  default     = "data"
}

variable "edge_subnet_tier" {
  description = "The Tier tag of the private subnets the internal load balancer runs in, in at least two availability zones."
  type        = string
  default     = "edge"
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
  default     = "123456789012.dkr.ecr.us-east-1.amazonaws.com/pathways-byo-vpc@sha256:0000000000000000000000000000000000000000000000000000000000000000"
}

variable "master_key_secret_arn" {
  description = "The Secrets Manager secret holding the master key: 32 random bytes in base64."
  type        = string
  default     = "arn:aws:secretsmanager:us-east-1:123456789012:secret:pathways-byo-vpc/master-key-AbCdEf"
}
