# cross-region-backup

One engine in the primary region, with the database's automated backups replicated to a second
region, and a restore there written out step by step.

## What it builds

In the primary region, in an existing VPC with a NAT gateway you already have:

- one engine on ECS Fargate, 1 vCPU and 2 GiB, and the migrate task definition;
- PostgreSQL on RDS, Multi-AZ, `db.t4g.medium`, deletion protection on, with 14 days of automated
  backups (`backup_retention_days`);
- an internal network load balancer with one MLLP listener, the KMS key, the secret, the log groups,
  the security groups and the roles;
- the one channel in [`project/`](project): ADT over MLLP in, admissions over MLLP out to the lab.

In the backup region (`backup_region`, `us-west-2` here):

- a replication of the database's automated backups
  (`aws_db_instance_automated_backups_replication`), kept for the same 14 days, so you can restore
  to any point in that window there;
- a KMS key, rotated yearly, with the alias `alias/pathways-backup-database`, which encrypts the
  replicated backups and any instance you restore from them.

Nothing runs in the backup region until you restore.

## When to choose it

When your data must survive the loss of a region, and a restore that takes you an hour or more is
an answer you can accept. It is the cheapest step towards disaster recovery: a copy of the data,
with no second engine and no second database running.

## What it costs

We give what bills, not prices: AWS sets those per region and changes them.

- Everything in the primary region, as in [`production`](../production) at the module's default
  sizes: Fargate, the database twice over for Multi-AZ, the network load balancer, the key, the
  secret, the logs and your NAT gateway.
- The replicated backups: storage per GB-month in the backup region, for the snapshots and the
  transaction logs of the retention window.
- Data transfer between regions, per GB, for each snapshot and log copied.
- The backup region's KMS key, per month and per request.
- A restore, while it runs: the instance, its storage and everything you deploy beside it.

## What it does not cover

- **Automatic promotion.** A standing engine in the second region that takes over when the first
  region fails is a different shape, and waits on the engine: see
  [`second-region-disaster-recovery`](../second-region-disaster-recovery). Here a person decides to
  restore and does it.
- **Messages after the restore point.** A restore brings back the database as it was at the time you
  choose, at most the latest restorable time RDS reports (usually a few minutes behind). Messages
  the engine accepted and acknowledged after that are not in it. Your senders will not resend what
  was acknowledged: reconcile with them.
- **The image and the master key in the backup region.** Replicate both before you need them: the
  image with ECR replication, and the master key's secret with Secrets Manager replication. A restored
  database is unreadable without the master key.
- **A network in the backup region**: a VPC, subnets in two zones, and the routes your senders and
  destinations need.

## Restore in the backup region

Do this only once the primary engine is stopped, or its region is gone: two engines on two copies of
the data both deliver, and a destination gets each message twice. Every name below is an example.

1. Find the latest point you can restore to, in the backup region:

   ```sh
   aws rds describe-db-instance-automated-backups --region us-west-2 \
     --query 'DBInstanceAutomatedBackups[?DBInstanceIdentifier==`pathways-backup`].[DBInstanceAutomatedBackupsArn,RestoreWindow.LatestTime]'
   ```

   The first value is also this example's output `replicated_backups_arn`.

2. Create, in the backup region, a DB subnet group in two availability zones, a security group for
   the database, and a parameter group of the same family (`postgres17`) with `rds.force_ssl` set to
   1, so the restored database refuses connections without TLS, as the module's does.

3. Restore into a new instance, encrypted, private and Multi-AZ:

   ```sh
   aws rds restore-db-instance-to-point-in-time --region us-west-2 \
     --source-db-instance-automated-backups-arn "$REPLICATED_BACKUPS_ARN" \
     --target-db-instance-identifier pathways-restored \
     --use-latest-restorable-time \
     --db-subnet-group-name pathways-restored \
     --vpc-security-group-ids "$DATABASE_SECURITY_GROUP_ID" \
     --db-parameter-group-name pathways-restored \
     --no-publicly-accessible --multi-az --deletion-protection
   aws rds wait db-instance-available --region us-west-2 --db-instance-identifier pathways-restored
   ```

   Use `--restore-time` instead of `--use-latest-restorable-time` to pick an earlier point.

4. Give it a new master password, since the old one is in the primary region's secret, and store the
   connection URL in a secret in the backup region. Read the password from a file or a prompt, never
   from the command line's history:

   ```sh
   aws rds modify-db-instance --region us-west-2 --db-instance-identifier pathways-restored \
     --master-user-password "$NEW_PASSWORD" --apply-immediately
   aws secretsmanager create-secret --region us-west-2 --name pathways-restored/database-url \
     --secret-string "postgres://pathways:${NEW_PASSWORD}@<restored address>:5432/pathways"
   ```

5. Deploy the module in the backup region on that database: the
   [`existing-database`](../existing-database) example, with `database_url_secret_arn` the new
   secret, `database_security_group_id` the database's group from step 2, the replicated master key
   secret and image, and the same `mllp_sources`. Run its migrate task before the engine, as for any
   deploy.

6. Point your senders at the new load balancer, through the DNS name they use, and check the engine
   reports ready. The old engine's engine lease in the restored database has long expired, so the new
   engine takes it.

When the primary region is back, do not start the old engine against its old database: that copy is
behind the restored one. Rebuild the primary from a backup of the restored database, or keep
running in the backup region.

## Use it

Every value in [`variables.tf`](variables.tf) is a placeholder. Copy `project/` into a project
`pathways init` made, add the RDS global bundle, the MLLP source's certificate and key and the lab's
CA under `certs/`, build the image and push it, set the variables, then plan and apply from your own
pipeline with your own credentials. Practise the restore before you need it. CI here validates this
directory and tests it against mocked providers (`tests/example-cross-region-backup`); nothing in this
repository applies it.
