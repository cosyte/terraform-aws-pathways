---
id: module-security-groups
title: The security_groups submodule
sidebar_label: security_groups
description: "Every input and output of modules/security_groups, generated from its code."
---

# The security_groups submodule

`modules/security_groups` holds who may reach the load balancers, the engine and the database. The root module calls it; to use it on its own, set `source = "github.com/cosyte/terraform-aws-pathways//modules/security_groups"`.

This page is generated from the code by `scripts/docs.sh`, and CI fails when it no longer matches, so it lists every input and output there is. Edit the descriptions in the `.tf` files, never here.

## Required inputs

### name

Name of the deployment. The groups are pathways-\<name\>-engine, -database, -nlb and -alb.

Type: `string`

Required: it has no default.

### vpc_id

The VPC the security groups belong to.

Type: `string`

Required: it has no default.

### allowed_cidr_blocks

The networks allowed to connect to the MLLP and HTTP sources through the load balancers. There is no default, so nothing is open until you say what is.

Type: `list(string)`

Required: it has no default.

## Optional inputs

### mllp_sources

The MLLP sources, by name, each with the port it listens on. Empty creates no network load balancer group.

Type:

```hcl
map(object({
    port = number
  }))
```

Default: `{}`

### http_sources

The HTTP sources, by name, each with the port it listens on. Empty creates no application load balancer group.

Type:

```hcl
map(object({
    port = number
  }))
```

Default: `{}`

### probe_port

The port of the engine's probe listener, which each load balancer may reach for its health checks.

Type: `number`

Default: `9091`

### egress_rules

Where the engine may connect, other than the database, which is always allowed: each rule is a TCP port and the networks it may reach. The default allows HTTPS anywhere, which the tasks need for the image registry, Secrets Manager and CloudWatch Logs through a NAT gateway; with VPC endpoints for those, narrow it.

Type:

```hcl
map(object({
    port        = number
    cidr_blocks = list(string)
  }))
```

Default:

```json
{
  "https": {
    "cidr_blocks": [
      "0.0.0.0/0"
    ],
    "port": 443
  }
}
```

### tags

Tags added to every group and rule. The caller's provider default_tags apply as well.

Type: `map(string)`

Default: `{}`

## Outputs

### engine_security_group_id

ID of the engine's security group. The database admits it.

### database_security_group_id

ID of the database's security group, which admits the engine's only.

### nlb_security_group_id

ID of the network load balancer's security group, or null when there is no MLLP source.

### alb_security_group_id

ID of the application load balancer's security group, or null when there is no HTTP source.
