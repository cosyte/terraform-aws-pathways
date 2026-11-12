---
id: deployment-shapes
title: Deployment shapes
sidebar_label: Deployment shapes
description: "How the module's pieces fit together, the shapes a deployment takes from the smallest to the complete one, and what drives each one's monthly bill."
---

# Deployment shapes

The module always creates the same core, and adds pieces as your project needs them. This page
explains what the core is, what each addition brings, and why the defaults are what they are.

## The core

Every deployment has:

- **One engine** on ECS Fargate, in your private subnets, as a service of one task. The engine lease
  refuses a second engine on the same database, so the service runs one, and a deploy stops the old
  task before it starts the new one.
- **A migrate task definition** on the same settings. The engine starts with `--no-migrate` and never
  changes the schema itself; your CI runs the migrate task before each deploy, so the schema moves at
  a step you can see and check.
- **PostgreSQL on RDS**, Multi-AZ by default, reachable only from the engine and refusing any
  connection without TLS. Its password is generated and written without ever entering the plan or
  the state, into a Secrets Manager secret that ECS injects as `PATHWAYS_DATABASE_URL`.
- **A KMS key**, rotated every year, which encrypts the database (unless you give
  `database_kms_key_arn`), its secret and the logs.
- **Two log groups**, for the engine and the migrate task, which get the engine's JSON lines: ids,
  counts and codes, never a message's content.

The module is a composition: the root's `main.tf` calls one submodule per concern (`kms`, `logs`,
`security_groups`, `database`, `iam`, `load_balancers`, `ecs`, and the optional `bucket` and `sftp`),
and each can be used on its own. The reference has [a page for each](./module-ecs.md).

## What a source adds

- **An MLLP source** (`mllp_sources`) adds a network load balancer, created with the first one, and a
  TCP listener per source that passes the connection straight to the engine, which terminates its own
  TLS.
- **An HTTP source** (`http_sources`) adds an application load balancer, created with the first one,
  and an HTTPS listener per source with your certificate.
- **No source** of either kind, as for a channel that only reads files, creates no load balancer.

Both load balancers check readiness on the probe listener, so traffic goes only to an engine that
holds the lease; ECS checks liveness and replaces a stalled engine.

## What file exchange adds

- **The bucket** (`bucket_enabled`): an S3 bucket the engine reaches through its task role, with no
  access key, for file sources and destinations.
- **SFTP** (`sftp_enabled`, which needs the bucket): an internal Transfer Family server whose users
  each see their own prefix of the bucket, so a partner's files and a channel meet in one place.

## The shapes the examples take

| Shape | Example | Engine and database | Load balancers | Bucket | SFTP |
| --- | --- | --- | --- | --- | --- |
| Smallest: one MLLP feed in and out | [minimal](./example-minimal.md) | 0.5 vCPU, 1 GiB; single-AZ `db.t4g.micro` | network | no | no |
| Complete: MLLP in, files out to a partner | [complete](./example-complete.md) | 1 vCPU, 2 GiB; Multi-AZ `db.t4g.medium` | network | yes | yes |

The minimal example is for trying the module out: before it carries real traffic, put
`database_multi_az` and `deletion_protection` back to their defaults.

## Why the defaults are what they are

- **Private by default.** The tasks get no public address, the load balancers are internal, the SFTP
  endpoint has no Elastic IP, and `allowed_cidr_blocks` has no default: nothing is reachable until you
  say from where. A wrong default here would expose patient data in your account.
- **Encrypted under one key the module scopes to the deployment**, with the longest deletion window
  AWS allows, so a destroy cannot make data unreadable sooner than it must. The trade-off is the
  final snapshot: see [Destroy a deployment](./destroy-a-deployment.md).
- **Least privilege.** The task role has no permissions but the bucket's, when the bucket is on. Each
  SFTP user's role reaches its own prefix alone.
- **Nothing logged beyond the engine's own lines.** No load balancer access logs, no Performance
  Insights, no PostgreSQL log export, no ECS Exec, and no Container Insights unless you turn it on.

## What drives the bill

We give the drivers, not prices: AWS sets those per region and changes them. Check each against the
[AWS Pricing Calculator](https://calculator.aws/) for your region.

- **The engine**: Fargate bills each task's vCPU and memory per second it runs. One engine runs all
  month, and the migrate task for a few minutes a deploy.
- **The database**: the instance class per hour, twice over with Multi-AZ, the storage allocated per
  GB-month, and backups beyond the database's own size.
- **The load balancers**: each bills per hour it exists and per load balancer capacity unit.
- **NAT and data transfer**: a NAT gateway bills per hour and per GB processed, VPC endpoints per hour
  and per GB, and data leaving AWS per GB.
- **Secrets, the key and the logs**: Secrets Manager per secret per month and per 10,000 calls; KMS
  per key per month and per request; CloudWatch Logs per GB ingested and per GB-month stored.
- **The bucket**: S3 per GB-month stored, noncurrent versions included, and per request.
- **SFTP**: Transfer Family per hour for each protocol enabled, whether or not anyone connects, and
  per GB transferred. For a small deployment that is often the largest line.

## Not here yet

- **Alarms** on the engine's own metrics.
- **A standby engine**: ECS replaces a task its load balancer reports unhealthy, and a standby is not
  ready by design, so it needs its own design and tests.
- **SFTP from the internet**, which needs Elastic IPs.

## Related

- [Place it in your network](./place-it-in-your-network.md),
  [Turn on the bucket](./turn-on-the-bucket.md) and [Give partners SFTP](./give-partners-sftp.md),
  which apply the choices above.
