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
