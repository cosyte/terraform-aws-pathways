---
id: place-it-in-your-network
title: Place it in your network
sidebar_label: Place it in your network
description: "Choose the subnets, who may reach the load balancers, where the engine may connect, and how it reaches the AWS APIs."
---

# Place it in your network

The module creates no VPC: it deploys into the VPC and subnets you name. This page goes through the
network inputs in the order you decide them.

## Choose the subnets

```hcl title="main.tf"
  vpc_id             = "vpc-0a1b2c3d4e5f60718"
  private_subnet_ids = ["subnet-0a1b2c3d4e5f60718", "subnet-0f1e2d3c4b5a60718"]

  # Optional; each is null by default, which uses private_subnet_ids.
  database_subnet_ids      = ["subnet-0b1c2d3e4f5a60718", "subnet-0e1f2a3b4c5d60718"]
  load_balancer_subnet_ids = ["subnet-0c1d2e3f4a5b60718", "subnet-0d1e2f3a4b5c60718"]
```

- **`private_subnet_ids`**: the engine's tasks and the migrate task, at least two subnets in two
  availability zones. The tasks get no public address.
- **`database_subnet_ids`**: the database, at least two subnets in two availability zones.
- **`load_balancer_subnet_ids`**: the load balancers. An internet-facing load balancer needs public
  subnets here.
- **`sftp_subnet_ids`**: the SFTP endpoint, with `sftp_enabled`.

## Say who may reach the sources

`allowed_cidr_blocks` has no default: nothing can connect until you name the networks your senders,
or your VPN, connect from. Each MLLP source gets a TCP listener on the network load balancer, and
each HTTP source an HTTPS listener on the application load balancer, open to those blocks on that
port alone.

```hcl title="main.tf"
  allowed_cidr_blocks = ["10.20.0.0/16"]

  mllp_sources = { adt = { port = 2575 } }
  http_sources = { orders = { port = 8443 } }

  alb_certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/<id>"
```

Both load balancers are internal by default (`load_balancer_internal = true`), reachable from inside
the VPC and what is connected to it. Set it to `false` only with public subnets in
`load_balancer_subnet_ids` and a narrow `allowed_cidr_blocks`. A load balancer exists only when you
name a source of its kind, and the two kinds together take at most five sources: an ECS service
attaches to at most five target groups.

The network load balancer passes MLLP straight through: the engine terminates its own TLS, so keep
each MLLP source's `tls` block in your project. The application load balancer's listeners are HTTPS
only, with the certificate in `alb_certificate_arn`, and reach the engine over
`http_target_protocol`: HTTPS by default, to an HTTP source with its own `tls` block, or HTTP, to one
with `plaintext: true`.

## Say where the engine may connect

The engine may always reach its database. Everything else is in `egress_rules`, one rule per TCP
port and the networks it may reach. The default is HTTPS anywhere, which the tasks need for the image
registry, Secrets Manager and CloudWatch Logs through a NAT gateway. Add a rule for each
destination's port, and keep the default rule when you do, since a map you set replaces it:

```hcl title="main.tf"
  egress_rules = {
    https = {
      port        = 443
      cidr_blocks = ["0.0.0.0/0"]
    }
    lab = {
      port        = 2576
      cidr_blocks = ["10.40.0.0/24"]
    }
  }
```

## Reach the AWS APIs

The tasks run in private subnets with no public address, so they reach the image registry, Secrets
Manager and CloudWatch Logs (and S3, with the bucket on) through a NAT gateway in your VPC, or
through VPC endpoints for those services. A NAT gateway bills per hour and per GB processed; endpoints bill per hour and per
GB too. With endpoints for every service the tasks use, narrow the `https` rule in `egress_rules` to
your VPC's range.

## Related

- [Deployment shapes](./deployment-shapes.md): which load balancers and options a deployment needs.
- [The security_groups submodule](./module-security-groups.md) and
  [the load_balancers submodule](./module-load-balancers.md).
- Every network input in [Inputs and outputs](./inputs-and-outputs.md#allowed_cidr_blocks).
