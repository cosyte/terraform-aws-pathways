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
