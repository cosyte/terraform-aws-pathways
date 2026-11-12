# production

One engine, sized and protected for real traffic, with the database's warm standby.

## What it builds

In an existing VPC, with a NAT gateway you already have:

- one engine on ECS Fargate, 2 vCPU and 4 GiB, as a service of one task, and the migrate task
  definition beside it. ECS replaces the engine if it stops, or if `pathways probe` reports it
  stalled;
- PostgreSQL on RDS, `db.m7g.large`, Multi-AZ: RDS keeps a synchronous standby in a second
  availability zone and fails over to it on its own, under the same hostname. 100 GiB of storage
  that may grow to 500, 35 days of automated backups, deletion protection on, and its storage,
  backups and final snapshot under a KMS key of your own (`database_kms_key_arn`);
- an internal network load balancer with one MLLP listener, the KMS key, the secret, the log
  groups, the security groups and the roles;
- the one channel in [`project/`](project): ADT over MLLP in, admissions over MLLP out to the lab.

## When to choose it

When one engine is enough for your traffic and a gap of one engine start, while ECS replaces a
failed task, is one your senders retry across. It is the shape to start production from: copy it,
then add the sources, the bucket or SFTP your project needs from the other examples.

## What it costs

We give what bills, not prices: AWS sets those per region and changes them.

- Fargate, per second, for 2 vCPU and 4 GiB, all month.
- The database instance per hour, twice over for the Multi-AZ standby, all month; storage per
  GB-month, twice over; and backups beyond the database's size, which 35 days of retention raises.
- The network load balancer per hour and per capacity unit.
- Your own KMS key and the module's, per month and per request; the secret; CloudWatch Logs per GB
  ingested and stored for 365 days.
- Your NAT gateway, per GB the tasks send through it.

## What it does not cover

- **A standby engine.** Pathways can run a second engine that waits with `pathways start --standby`
  and takes the engine lease when the first stops. This module does not run one yet: ECS replaces a
  task its load balancer reports unhealthy, and a standby is not ready by design, so it needs its own
  design and tests here first. Until then, a failed engine is replaced by ECS, which takes one engine
  start.
- Several active engines, blue and green deploys, and a second region: see
  [`multiple-active-nodes`](../multiple-active-nodes), [`blue-green`](../blue-green) and
  [`second-region-disaster-recovery`](../second-region-disaster-recovery).
- Backups in another region: see [`cross-region-backup`](../cross-region-backup).
- Alarms: turn them on with `alarms_enabled`, as [`alarms`](../alarms) does.
- The KMS key for the database, which you create and keep outside this example.

## Use it

Every value in [`variables.tf`](variables.tf) is a placeholder. Copy `project/` into a project
`pathways init` made, add the RDS global bundle, the MLLP source's certificate and key and the lab's
CA under `certs/`, build the image and push it, set the variables, then plan and apply from your own
pipeline with your own credentials. CI here validates this directory and tests it against mocked
providers (`tests/example-production`); nothing in this repository applies it.
