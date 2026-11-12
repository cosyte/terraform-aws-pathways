# Changelog

## Unreleased (patch)

- The module: Pathways on ECS Fargate, with PostgreSQL on RDS (encrypted, TLS forced), the database
  URL in Secrets Manager, a KMS key, a network load balancer for MLLP, an application load balancer
  for HTTP, readiness health checks, a migrate task definition, a drain setting, and encrypted log
  groups. Tested with `terraform test` against mocked providers, tflint and trivy. Alarms and a
  standby engine are not in it yet.
- `container_insights`, off by default: Container Insights writes to a log group that is not under
  the module's key, so the module turns it on only when you ask.
- `database_kms_key_arn`: a key of your own for the database, its backups and its final snapshot, so
  the snapshot can outlive the module's key after a destroy. Null keeps the module's key.
- The module is now a composition of nested submodules under `modules/` (`kms`, `logs`,
  `security_groups`, `database`, `iam`, `load_balancers`, `ecs`), each with its own README and each
  usable on its own. The root's inputs and outputs keep their names and types. `terraform test`
  covers the root and each submodule, from `tests/<subject>/`, and the gate's scripts live in
  `scripts/`.
- The README says how to bring the database password and its stored URL back together (raise
  `database_password_version`), what a destroy does to the final snapshot, and the documented ranges
  for the stop timeout and the deregistration delay.
- Two optional submodules, both off by default. `modules/bucket` (`bucket_enabled`): an S3 bucket
  encrypted under the module's key, versioned, public access blocked, TLS only, with lifecycle rules
  as an input and server access logs to a second bucket; the task role may use it and the engine gets
  its name as `PATHWAYS_BUCKET`, so a channel's `s3` block needs no credential. `modules/sftp`
  (`sftp_enabled`): an AWS Transfer Family SFTP server on an internal VPC endpoint, reachable from
  `sftp_allowed_cidr_blocks` alone (`0.0.0.0/0` refused), with service managed users on SSH keys,
  each locked to a home prefix in the bucket, logging to a log group under the module's key.
- `examples/complete` stands up the engine, the database, the bucket, SFTP and one channel, with the
  project it deploys. The README lists the monthly cost drivers and says a deployment needs your own
  Business Associate Addendum with AWS.
- Documentation for docs.cosyte.com in `docs-content/`: a quickstart that deploys the smallest
  example, how-to guides for the network, the bucket, SFTP, upgrades and a destroy, an explanation of
  the deployment shapes and what drives their cost, troubleshooting, the two quality pages, every
  input and output of the root and of each submodule (generated from the code by `scripts/docs.sh`,
  which CI runs), and a page per example with its files, what it deploys and what it costs to leave
  running. CI fails when an example has no page. The README links to the docs site.
- `examples/minimal`: the smallest deployment, one engine, its database in one availability zone and
  one MLLP channel, which the quickstart deploys.
- An existing database: `database_url_secret_arn`, a Secrets Manager secret of your own holding a
  PostgreSQL URL, with `database_security_group_id`, that database's security group. Given both, the
  module creates no RDS instance, no subnet group and no URL secret, injects your secret as
  `PATHWAYS_DATABASE_URL`, lets the engine reach your group on 5432 and adds a rule to it admitting
  the engine. Neither given keeps the module's own database. A caller who changes nothing changes
  nothing: the database and its security group move to `module.database[0]` and
  `aws_security_group.database[0]` through `moved` blocks, so a plan shows no replacement.
  `modules/security_groups` takes `database_security_group_id` too.
- Two outputs, `database_instance_arn` and `database_storage_kms_key_arn`, for a replication of the
  database's automated backups to another region; both null with an existing database.
- One example per deployment shape, each with a README (what it builds, when to choose it, what it
  costs, what it does not cover), a docs page and a `tests/example-<name>` directory that plans it
  whole against mocked providers: `production` (one engine, the database's Multi-AZ standby, a key of
  your own), `bring-your-own-vpc` (a VPC and subnets found by their tags), `existing-database`,
  `mllp-only`, `http-only`, `sftp-and-bucket`, `private-only` (VPC endpoints, no NAT gateway) and
  `cross-region-backup` (replicated backups, with the restore written out). `minimal` and `complete`
  get their tests too. `multiple-active-nodes`, `blue-green` and `second-region-disaster-recovery`
  hold a README alone, saying they are not yet supported and what in the engine they wait on.
  `scripts/validate.sh` refuses an example folder with no `main.tf` that holds anything but its
  README; `scripts/test.sh` refuses an example with Terraform and no test directory, and runs only the
  subjects named on its command line when given any. The README has an index of the examples.
- A release workflow: a tag `vMAJOR.MINOR.PATCH` on main, with a `CHANGELOG.md` section of its
  version, creates the GitHub release with `docs-content.tar.gz` and `source.tar.gz` attached and
  tells docs.cosyte.com.
- The README and the deployment shapes page no longer say alarms wait on the engine publishing its
  metric names: the engine serves them at `/metrics` on its health endpoint, and the module runs no
  collector and creates no alarm on them yet. Nothing a caller passes changes.
