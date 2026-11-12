# existing-database

Pathways on a PostgreSQL database you already run, instead of the RDS instance the module creates.

## What it builds

In an existing VPC, beside your database:

- one engine on ECS Fargate, 1 vCPU and 2 GiB, and the migrate task definition, which migrates your
  database's schema when your CI runs it;
- no database: with `database_url_secret_arn` the module creates no RDS instance, no subnet group, no
  parameter group and no URL secret. ECS injects your secret as `PATHWAYS_DATABASE_URL`;
- two security group rules for `database_security_group_id`: the engine may reach your database's
  group on 5432, and your database's group admits the engine on 5432;
- an internal network load balancer with one MLLP listener, the KMS key (for the logs), the log
  groups, the engine's security groups and the roles;
- the one channel in [`project/`](project): ADT over MLLP in, admissions over MLLP out to the lab.

## When to choose it

When a database team already runs PostgreSQL for you, with its own backups, patching, monitoring
and failover, and Pathways should be one more database on it. Or when you restore a backup into a
new instance, as [`cross-region-backup`](../cross-region-backup) describes, and point a deployment
at it.

## What your database needs

- PostgreSQL that Pathways supports, reachable from the engine's subnets on 5432.
- A database and a user that are Pathways' alone: the migrate task creates and changes its tables.
- TLS. The engine verifies the server's certificate against `tls.ca` in `pathways.yaml`: for RDS or
  Aurora, the RDS global bundle. Set `rds.force_ssl` on the database's side.
- The secret: one `postgres://` URL with the user and password, in a Secrets Manager secret. If a
  customer managed key encrypts it, list that key in `database_url_secret_kms_key_arns`.

## What it costs

We give what bills, not prices: AWS sets those per region and changes them.

- Fargate, per second, for 1 vCPU and 2 GiB, all month.
- The network load balancer per hour and per capacity unit.
- The module's KMS key, and CloudWatch Logs per GB ingested and stored.
- Your NAT gateway, per GB the tasks send through it.
- The database is on your own bill already. Pathways adds its storage, and its connections and load.

## What it does not cover

- The database itself: its backups, its encryption, its failover, its version upgrades and its
  password rotation are yours. After you rotate the password, update the secret and restart the
  engine (a new deployment of the service) so it reads the new URL.
- A port other than 5432: the module's rules are on 5432.
- A database in another VPC: the two rules name security groups, which works within one VPC (and
  across a peering in the same region). We have not tested other routes to a database.
- The other `database_` inputs (`database_instance_class` and the rest) do nothing with an existing
  database.

## Use it

Every value in [`variables.tf`](variables.tf) is a placeholder. Create the database and user, store
the URL in a secret, copy `project/` into a project `pathways init` made, add the CA bundle for your
database, the MLLP source's certificate and key and the lab's CA under `certs/`, build the image and
push it, set the variables, then plan and apply from your own pipeline with your own credentials. CI
here validates this directory and tests it against mocked providers
(`tests/example-existing-database`); nothing in this repository applies it.
