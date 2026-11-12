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
  description = "Private subnets in two availability zones, with a route to a NAT gateway. The SFTP endpoint goes in them too."
  type        = list(string)
  default     = ["subnet-0a1b2c3d4e5f60718", "subnet-0f1e2d3c4b5a60718"]
}

variable "sftp_allowed_cidr_blocks" {
  description = "The networks the lab and the clinic connect to SFTP from, over your VPN or another private link."
  type        = list(string)
  default     = ["10.30.0.0/24", "10.31.0.0/24"]
}

variable "image" {
  description = "Your project's image, by digest."
  type        = string
  default     = "123456789012.dkr.ecr.us-east-1.amazonaws.com/pathways-files@sha256:0000000000000000000000000000000000000000000000000000000000000000"
}

variable "master_key_secret_arn" {
  description = "The Secrets Manager secret holding the master key: 32 random bytes in base64."
  type        = string
  default     = "arn:aws:secretsmanager:us-east-1:123456789012:secret:pathways-files/master-key-AbCdEf"
}

variable "lab_public_key" {
  description = "The lab's SSH public key, one OpenSSH line. The placeholder is no real key."
  type        = string
  default     = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA lab-key"
}

variable "clinic_public_key" {
  description = "The clinic's SSH public key, one OpenSSH line. The placeholder is no real key."
  type        = string
  default     = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB clinic-key"
}
