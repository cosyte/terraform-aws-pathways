variable "region" {
  description = "The AWS region to deploy into. The endpoints' service names are built from it."
  type        = string
  default     = "us-east-1"
}

variable "vpc_id" {
  description = "The VPC to deploy into. Its engine subnets route to no internet gateway and no NAT gateway."
  type        = string
  default     = "vpc-0a1b2c3d4e5f60718"
}

variable "private_subnet_ids" {
  description = "Private subnets in two availability zones, with no route to the internet. The interface endpoints go in them too."
  type        = list(string)
  default     = ["subnet-0a1b2c3d4e5f60718", "subnet-0f1e2d3c4b5a60718"]
}

variable "private_route_table_ids" {
  description = "The route tables of private_subnet_ids, which get the S3 gateway endpoint's route."
  type        = list(string)
  default     = ["rtb-0a1b2c3d4e5f60718", "rtb-0f1e2d3c4b5a60718"]
}

variable "allowed_cidr_blocks" {
  description = "The networks your MLLP sender connects from: inside the VPC, or connected to it privately."
  type        = list(string)
  default     = ["10.20.0.0/16"]
}

variable "lab_cidr_blocks" {
  description = "The networks the lab's MLLP receiver is in, reached privately, on port 2576."
  type        = list(string)
  default     = ["10.40.0.0/24"]
}

variable "image" {
  description = "Your project's image, by digest, in ECR in this region: with no NAT gateway the task cannot reach another registry."
  type        = string
  default     = "123456789012.dkr.ecr.us-east-1.amazonaws.com/pathways-private@sha256:0000000000000000000000000000000000000000000000000000000000000000"
}

variable "master_key_secret_arn" {
  description = "The Secrets Manager secret holding the master key: 32 random bytes in base64."
  type        = string
  default     = "arn:aws:secretsmanager:us-east-1:123456789012:secret:pathways-private/master-key-AbCdEf"
}
