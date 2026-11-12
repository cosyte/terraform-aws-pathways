# terraform-aws-pathways

A Terraform module that runs [Cosyte Pathways](https://github.com/cosyte/pathways), our open-source
healthcare integration engine, on AWS ECS Fargate, with its database, its secrets, its key, its load
balancers and its logs. It deploys your project's own image, named by digest.

**Status: not released yet.** The module is here and tested against mocked providers, but nothing is
tagged or published to a registry, and it has not been applied to a real account by us yet. Read it,
plan it, and tell us what you find.

## What it creates

- **The engine**: an ECS cluster, a Fargate task definition and a service that runs one engine
  (`pathways start --no-migrate`). Scale it up with `cpu` and `memory`. The tasks run in your private
  subnets with no public address, and ECS Exec is off.
- **A migrate task definition**: `pathways migrate` on the same settings, which your CI runs with ECS
  RunTask before each deploy. The engine itself never changes the schema.
- **PostgreSQL on RDS**: Multi-AZ by default, storage encrypted under the module's key, not publicly
  accessible, reachable only from the engine, and refusing any connection without TLS
  (`rds.force_ssl`). The password is generated and written without ever entering the plan or the
  state, into a Secrets Manager secret that ECS injects as `PATHWAYS_DATABASE_URL`.
- **A KMS key**, rotated every year, for the database, its secret and the logs.
- **A network load balancer** for your MLLP sources, one TCP listener per source, passed straight
  through to the engine, which terminates its own TLS.
- **An application load balancer** for your HTTP sources, HTTPS only (TLS 1.3 policy), dropping
  invalid headers.
- **Health checks**: the load balancers check readiness (`/readyz` on the probe listener), so traffic
  goes only to the engine that holds the lease; ECS checks liveness (`pathways probe`, which asks
  `/livez`) and replaces a stalled engine.
- **Logs**: two CloudWatch log groups, encrypted under the module's key, with a retention. They get
  the engine's own JSON lines, which hold ids, counts and codes and never a message's content. The
  module captures nothing more: no load balancer access logs, no Performance Insights, no PostgreSQL
  log export, no ECS Exec session logs.

Both load balancers are internal by default, and each exists only when you name a source of its
kind. The module has no provider block: your `aws` provider, its region and its `default_tags`
apply.

## Usage

```hcl
module "pathways" {
  source = "github.com/cosyte/terraform-aws-pathways"

  name                = "integration"
  vpc_id              = "vpc-0a1b2c3d4e5f60718"
  private_subnet_ids  = ["subnet-0a1b2c3d4e5f60718", "subnet-0f1e2d3c4b5a60718"]
  allowed_cidr_blocks = ["10.20.0.0/16"]

  image = "123456789012.dkr.ecr.us-east-1.amazonaws.com/integration@sha256:<digest>"

  mllp_sources = { adt = { port = 2575 } }
  http_sources = { orders = { port = 8443 } }

  alb_certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/<id>"

  environment = { PATHWAYS_STORAGE = "postgres" }
  secrets     = { PATHWAYS_KEY_2026_11 = "arn:aws:secretsmanager:us-east-1:123456789012:secret:integration/master-key-AbCdEf" }
}
```

[`examples/complete`](examples/complete) is the same as a whole root module. Every input is
described in [`variables.tf`](variables.tf) and every output in [`outputs.tf`](outputs.tf).

## What your project needs

The module runs the image you give it; your `pathways.yaml` has to match what the module wires up.

```yaml title="pathways.yaml"
storage:
  kind: { env: PATHWAYS_STORAGE, default: sqlite }
  postgres:
    url: { env: PATHWAYS_DATABASE_URL }
    tls: { ca: certs/rds-global-bundle.pem }
encryption:
  keys: [{ id: "2026-11", env: PATHWAYS_KEY_2026_11 }]
  current: "2026-11"
probes:
  port: 9091
  host: 0.0.0.0
  plaintext: true
```

- **`probes`**, on `probe_port` (9091 by default) and on `host: 0.0.0.0`, so the load balancers and
  the container health check reach it. Without it the engine never turns healthy.
- **`storage.postgres.url`** from `PATHWAYS_DATABASE_URL`, which the module sets. The database
  refuses connections without TLS, and its certificate is signed by the Amazon RDS certificate
  authority, which Node does not trust by default: add the RDS global bundle
  (`https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem`) to your image and name it in
  `tls.ca`.
- **The master key** in a Secrets Manager secret of your own, 32 random bytes in base64
  (`openssl rand -base64 32`), passed in `secrets` under the variable your `encryption` block reads.
  If that secret uses a customer managed key, list the key in `secrets_kms_key_arns`.
- **Each source's port** in `mllp_sources` or `http_sources`. An MLLP source keeps its own `tls`
  block; an HTTP source with its own `tls` block is reached over HTTPS (`http_target_protocol`, the
  default), or with `plaintext: true` over HTTP.

Everything else your configuration reads with `{ env: NAME }` goes in `environment` (plain values) or
`secrets` (ARNs). ECS reads each secret when a task starts; no engine change is needed.

## Deploy

A deploy is a new image digest. Because the engine starts with `--no-migrate`, the schema moves first,
through the migrate task, and ECS RunTask cannot change a task's image, so the migrate task definition
has its own image, `migrate_image`. Your CI does three steps, with no Terraform provisioner:

1. Apply with `migrate_image` set to the new image and `image` unchanged. Only the migrate task
   definition gets a new revision.
2. Run it, wait for it to stop, and check it exited 0:

   ```sh
   task=$(aws ecs run-task --cluster "$CLUSTER" --launch-type FARGATE \
     --task-definition "$MIGRATE_TASK_DEFINITION_ARN" \
     --network-configuration "$MIGRATE_NETWORK_CONFIGURATION" \
     --query 'tasks[0].taskArn' --output text)
   aws ecs wait tasks-stopped --cluster "$CLUSTER" --tasks "$task"
   code=$(aws ecs describe-tasks --cluster "$CLUSTER" --tasks "$task" \
     --query 'tasks[0].containers[0].exitCode' --output text)
   test "$code" = "0"
   ```

   The values come from the outputs `cluster_name`, `migrate_task_definition_arn` and
   `migrate_network_configuration`. The CI role needs `ecs:RunTask`, `ecs:DescribeTasks` and
   `iam:PassRole` on `execution_role_arn` and `task_role_arn`.
3. Apply with `image` set to the new image (and `migrate_image` back to null). The service replaces
   the engine.

`pathways migrate` applies expand steps only, which the running engine works on, so steps 1 and 2 are
safe while the old engine runs. A contract step waits for `pathways migrate --contract`, which is
yours to run when every engine is on the new version.

### One engine, and how it stops

The service runs one engine: the engine lease refuses a second on the same database. A deploy stops
the old task before it starts the new one (minimum healthy 0 %, maximum 100 %), so there is a gap of
one engine start, which your senders must retry across.

When ECS stops the engine it deregisters it from the load balancers, which wait
`drain_timeout_seconds` for open connections and then close them. ECS then sends SIGTERM: the engine
turns not ready, closes its sources and finishes what it is storing, and gets
`drain_timeout_seconds` again before SIGKILL. Fargate allows at most 120 seconds there, so the input
does too.

## Not here yet

- **Alarms.** CloudWatch alarms on the engine's own metrics, through a collector sidecar, come once
  the engine publishes its metric names.
- **A standby.** Pathways can run a second engine as a standby that takes over the lease. On ECS that
  needs care: ECS replaces a task its load balancer reports unhealthy, and a standby is not ready by
  design. It comes with its own tests.
- **A registry release.** No version is tagged or published yet.

## Security scanning

`tests/policy/run.sh` runs tflint with the AWS ruleset and `trivy config` at HIGH and CRITICAL. One
finding is accepted, inline where it fires:

| Check | Where | Why |
| --- | --- | --- |
| `AVD-AWS-0104` (egress to any address) | `security_groups.tf`, `aws_vpc_security_group_egress_rule.engine` | The default `egress_rules` allow HTTPS anywhere, which a task needs to reach the image registry, Secrets Manager and CloudWatch Logs through a NAT gateway. With VPC endpoints for those, narrow `egress_rules`. |

## Compliance

Running Pathways in your account keeps messages in your account. We sign Business Associate
Agreements. A module cannot make a deployment compliant on its own: what you run on it, who can
reach it and how you operate it are yours to decide.

## License

MIT. See [LICENSE](LICENSE).
