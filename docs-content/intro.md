---
id: intro
title: Pathways on AWS
sidebar_label: Overview
description: "A Terraform module that runs Pathways, our open-source healthcare integration engine, on AWS ECS Fargate with its database, key, load balancers and logs."
---

# Pathways on AWS

`terraform-aws-pathways` is a Terraform module that runs
[Pathways](https://docs.cosyte.com/pathways/), our open-source healthcare integration engine, on AWS
ECS Fargate, in an AWS account and VPC of your own. It deploys your project's own image, named by
digest, with everything the engine needs around it: a PostgreSQL database, a key, the secrets, the
load balancers and the logs. When you ask for them, it adds an S3 bucket and an SFTP server for file
exchange, and CloudWatch alarms on the engine's own metrics.

> **Not released yet.** The module is tested against mocked providers, but no version is tagged or
> published to a registry, and we have not applied it to a real account yet. Read it, plan it, and
> tell us what you find.

## What it creates

- **The engine**: an ECS cluster, a Fargate task definition and a service that runs one engine, in
  your private subnets with no public address.
- **A migrate task definition**: `pathways migrate` on the same settings, which your CI runs before
  each deploy.
- **PostgreSQL on RDS**: Multi-AZ by default, encrypted, reachable only from the engine, refusing
  connections without TLS. Its password never enters the plan or the state.
- **A KMS key**, rotated every year, for the database, its secret and the logs.
- **A network load balancer** for your MLLP sources and **an application load balancer** for your
  HTTP sources, each internal by default and each created only when you name a source of its kind.
- **Two CloudWatch log groups**, encrypted under the module's key.
- **Optional**: an S3 bucket (`bucket_enabled`) and an AWS Transfer Family SFTP server in front of it
  (`sftp_enabled`), and four CloudWatch alarms on the engine's metrics, read by a collector beside
  the engine (`alarms_enabled`, see [Turn on the alarms](./turn-on-the-alarms.md)), all off by
  default.

The module has no provider block: your `aws` provider, its region and its `default_tags` apply.

## Who it is for

Teams that run Pathways in their own AWS account and manage it with Terraform: the module is secure
by default (private networking, encryption at rest and in transit, least privilege), and every
setting it takes is an input you can read in [Inputs and outputs](./inputs-and-outputs.md).

## What it is not

- **Not a VPC.** It deploys into a VPC and subnets you already have, with a NAT gateway or VPC
  endpoints for the AWS APIs. See [Place it in your network](./place-it-in-your-network.md).
- **Not your project.** It runs the image you build: your channels and your `pathways.yaml` stay in
  your project's repository.
- **Not a compliance program.** We sign Business Associate Agreements. Your deployment also needs
  your own Business Associate Addendum with AWS, and what you run on it and how you operate it are
  yours to decide.

## Where to go next

- [Installation](./installation.md): what you need before you plan.
- [Quickstart](./quickstart.md): deploy the smallest example, then take it down.
- [Deployment shapes](./deployment-shapes.md): how the pieces fit, and what each costs.
- [Examples](./example-minimal.md): whole root modules that call this one.
