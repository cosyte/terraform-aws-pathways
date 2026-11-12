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

variable "hospital_cidr_blocks" {
  description = "The networks the hospital system sends ADT from."
  type        = list(string)
  default     = ["10.20.0.0/16"]
}

variable "lab_cidr_blocks" {
  description = "The lab's networks: it sends results from here, and its MLLP receiver for ADT listens here on port 2576."
  type        = list(string)
  default     = ["10.40.0.0/24"]
}

variable "ehr_cidr_blocks" {
  description = "The networks the EHR's MLLP receiver for results is in, which the engine may reach on port 2578."
  type        = list(string)
  default     = ["10.50.0.0/24"]
}

variable "image" {
  description = "Your project's image, by digest."
  type        = string
  default     = "123456789012.dkr.ecr.us-east-1.amazonaws.com/pathways-mllp-only@sha256:0000000000000000000000000000000000000000000000000000000000000000"
}

variable "master_key_secret_arn" {
  description = "The Secrets Manager secret holding the master key: 32 random bytes in base64."
  type        = string
  default     = "arn:aws:secretsmanager:us-east-1:123456789012:secret:pathways-mllp-only/master-key-AbCdEf"
}
