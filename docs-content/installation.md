---
id: installation
title: Installation
sidebar_label: Installation
description: "What you need before you plan the module: Terraform, the AWS provider, a VPC with private subnets, your project's image and a master key."
---

# Installation

The module is a Terraform module, so there is nothing to install beyond Terraform: you call it from
a root module of your own, and `terraform init` fetches it.

## What you need

- **Terraform 1.11 or later**, and the `hashicorp/aws` provider from 6.0 up to, not including, 7.0.
  The module also uses `hashicorp/random`. `versions.tf` holds the constraints.
- **An AWS account**, and credentials in your own pipeline that may create the resources listed in
  the [overview](./intro.md). Nothing in this repository applies the module or holds a credential.
- **A VPC** with private subnets in at least two availability zones, and a route from them to the
  AWS APIs: a NAT gateway, or VPC endpoints. See
  [Place it in your network](./place-it-in-your-network.md).
- **Your project's image**, built on the Pathways image with your channels inside it, pushed to a
  registry and named by digest. See
  [Deploy the image](https://docs.cosyte.com/pathways/deploy-the-image) in the Pathways docs.
- **A master key** for the engine's stored messages: 32 random bytes in base64
  (`openssl rand -base64 32`), in a Secrets Manager secret of your own.

## Call the module

Name the source and a version. Until the first release is tagged, name a commit:

```hcl
module "pathways" {
  source = "github.com/cosyte/terraform-aws-pathways?ref=<commit or tag>"

  vpc_id              = "vpc-0a1b2c3d4e5f60718"
  private_subnet_ids  = ["subnet-0a1b2c3d4e5f60718", "subnet-0f1e2d3c4b5a60718"]
  allowed_cidr_blocks = ["10.20.0.0/16"]

  image = "123456789012.dkr.ecr.us-east-1.amazonaws.com/integration@sha256:<digest>"
}
```

Those four inputs are the only ones without a default. Every value above is a placeholder.

```sh
terraform init
terraform plan
```

## Next

The [Quickstart](./quickstart.md) deploys a whole working example. Every input and output is in
[Inputs and outputs](./inputs-and-outputs.md).
