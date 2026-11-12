---
id: module-load-balancers
title: The load_balancers submodule
sidebar_label: load_balancers
description: "Every input and output of modules/load_balancers, generated from its code."
---

# The load_balancers submodule

`modules/load_balancers` holds the network load balancer for MLLP and the application load balancer for HTTP. The root module calls it; to use it on its own, set `source = "github.com/cosyte/terraform-aws-pathways//modules/load_balancers"`.

This page is generated from the code by `scripts/docs.sh`, and CI fails when it no longer matches, so it lists every input and output there is. Edit the descriptions in the `.tf` files, never here.

## Required inputs

### name

Name of the deployment. It prefixes the load balancer and target group names, which AWS caps at 32 characters.

Type: `string`

Required: it has no default.

### vpc_id

The VPC of the target groups.

Type: `string`

Required: it has no default.

### subnet_ids

Subnets for the load balancers, in at least two availability zones. An internet-facing load balancer (internal = false) needs public subnets here.

Type: `list(string)`

Required: it has no default.

## Optional inputs

### internal

Whether the load balancers are internal, reachable only from inside the VPC and what is connected to it. The default; set false only with public subnets and narrow security groups.

Type: `bool`

Default: `true`

### mllp_sources

The MLLP sources, by name, each with the port it listens on. Each gets a TCP listener on the network load balancer, on the same port, passed through to the engine, which terminates its own TLS. Empty creates no network load balancer.

Type:

```hcl
map(object({
    port = number
  }))
```

Default: `{}`

### http_sources

The HTTP sources, by name, each with the port it listens on. Each gets an HTTPS listener on the application load balancer, on the same port, forwarding to the engine with http_target_protocol. Empty creates no application load balancer.

Type:

```hcl
map(object({
    port = number
  }))
```

Default: `{}`

### nlb_security_group_id

ID of the network load balancer's security group. Needed when mllp_sources is not empty.

Type: `string`

Default: `null`

### alb_security_group_id

ID of the application load balancer's security group. Needed when http_sources is not empty.

Type: `string`

Default: `null`

### http_target_protocol

How the application load balancer reaches the engine's HTTP sources: HTTPS, to an HTTP source with its own tls block (the default), or HTTP, to one with plaintext: true.

Type: `string`

Default: `"HTTPS"`

### alb_certificate_arn

ARN of the ACM certificate the application load balancer's HTTPS listeners present. Needed when http_sources is not empty.

Type: `string`

Default: `null`

### alb_ssl_policy

The TLS policy of the application load balancer's HTTPS listeners.

Type: `string`

Default: `"ELBSecurityPolicy-TLS13-1-2-2021-06"`

### probe_port

The port of the engine's probe listener. The target groups check /readyz on it.

Type: `number`

Default: `9091`

### drain_timeout_seconds

The target groups' deregistration delay: how long they wait for a stopping engine's open connections before closing them.

Type: `number`

Default: `60`

### deletion_protection

Whether the load balancers refuse deletion. Turn it off, and apply, before you destroy the module.

Type: `bool`

Default: `true`

### tags

Tags added to every resource the module creates. The caller's provider default_tags apply as well.

Type: `map(string)`

Default: `{}`

## Outputs

### nlb_arn

ARN of the network load balancer, or null when there is none.

### nlb_dns_name

DNS name of the network load balancer for the MLLP sources, or null when there is none.

### nlb_zone_id

Hosted zone ID of the network load balancer, for a Route 53 alias record, or null.

### alb_arn

ARN of the application load balancer, or null when there is none.

### alb_dns_name

DNS name of the application load balancer for the HTTP sources, or null when there is none.

### alb_zone_id

Hosted zone ID of the application load balancer, for a Route 53 alias record, or null.

### mllp_target_group_arns

ARN of each MLLP source's target group, by source name. Read after the listeners exist.

### http_target_group_arns

ARN of each HTTP source's target group, by source name. Read after the listeners exist.
