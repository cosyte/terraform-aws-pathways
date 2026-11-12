# terraform-aws-pathways

A Terraform module that runs [Cosyte Pathways](https://github.com/cosyte/pathways), our open-source
healthcare integration engine, on AWS ECS Fargate, with its database, its secrets, its key, its load
balancers and its logs, and, when you ask for them, an S3 bucket and an SFTP server for file
exchange. It deploys your project's own image, named by digest.

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
- **A KMS key**, rotated every year, for the database (unless you give `database_kms_key_arn`), its
  secret and the logs.
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
  log export, no ECS Exec session logs, and no Container Insights unless you turn it on with
  `container_insights`. Container Insights writes performance metrics only (CPU, memory, network,
  task counts), never message content, to a log group AWS creates
  (`/aws/ecs/containerinsights/<cluster>/performance`) that is not encrypted under the module's key,
  and CloudWatch bills for it.

Two more, each off until you turn it on:

- **An S3 bucket** (`bucket_enabled`) for file sources and destinations: encrypted under the
  module's key with an S3 Bucket Key, versioned, all public access blocked, ACLs off, refusing any
  request without TLS 1.2 or later, with lifecycle rules you set (`bucket_lifecycle_rules`) and
  server access logs to a second, private bucket. The engine's task role may list the bucket and
  read, write and delete its objects, and the engine gets its name as `PATHWAYS_BUCKET`, so a
  channel's `s3` block reads `bucket: { env: PATHWAYS_BUCKET }` and no access key exists.
- **An SFTP server** (`sftp_enabled`, which needs the bucket): AWS Transfer Family on a VPC endpoint
  with no Elastic IP, so it is internal to your VPC, reachable on port 22 from
  `sftp_allowed_cidr_blocks` alone (`0.0.0.0/0` is refused). Its users (`sftp_users`) sign in with
  SSH public keys, never a password, and each is locked to its home prefix in the bucket, by a
  logical home directory and by a role that reaches that prefix alone. It logs to a CloudWatch log
  group encrypted under the module's key.

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

[`examples/complete`](examples/complete) stands the whole thing up as a root module: the engine and
its database, the bucket, SFTP for one partner, and the one channel that joins them, with the
project it deploys in `examples/complete/project`. Every input is
described in [`variables.tf`](variables.tf) and every output in [`outputs.tf`](outputs.tf).

## Layout

The root module is the composition: its `main.tf` calls one submodule per concern and wires them
together. Each submodule follows the registry's standard layout and can be used on its own, as its
README shows, with `source = "github.com/cosyte/terraform-aws-pathways//modules/<name>"`.

```text
.
├── main.tf                  the composition: calls each submodule
├── variables.tf             the root's inputs
├── outputs.tf               the root's outputs
├── versions.tf              Terraform and provider constraints
├── modules/
│   ├── kms/                 the customer managed key, rotated yearly
│   ├── logs/                the engine's and the migrate task's log groups
│   ├── security_groups/     who may reach the load balancers, the engine and the database
│   ├── database/            PostgreSQL on RDS and the secret holding its URL
│   ├── iam/                 the task execution role and the task role
│   ├── load_balancers/      the network load balancer (MLLP) and application load balancer (HTTP)
│   ├── ecs/                 the cluster, the engine and migrate task definitions, the service
│   ├── bucket/              optional: the S3 bucket, its access log bucket, the task role's access
│   └── sftp/                optional: the Transfer Family SFTP server, its users and its logs
├── examples/
│   └── complete/            a whole root module that calls this one, and the project it deploys
├── tests/
│   ├── composition/         the root: the wiring between the submodules, its outputs and inputs
│   └── <name>/              one per submodule (kms, logs, ...), each tested on its own
└── scripts/
    ├── check-no-emdash.sh   no em or en dash in any tracked file
    ├── validate.sh          the layout, then terraform validate in every directory
    ├── policy.sh            tflint and trivy
    └── test.sh              terraform test per subject, mocked providers, plan only
```

Each submodule directory holds `main.tf`, `variables.tf`, `outputs.tf`, `versions.tf` and a
`README.md`. The tests plan against mocked providers only: none needs an AWS account or creates
anything.

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

- **With `bucket_enabled`**, a file source or destination's `s3` block names the bucket with
  `bucket: { env: PATHWAYS_BUCKET }` and nothing else: the AWS SDK finds the task role and the region
  on its own. Keep partners' files under their SFTP home prefixes, such as `partners/lab/outbox`.

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
`drain_timeout_seconds` again before SIGKILL. The input takes 2 to 120 seconds, the range both sides
allow:

- The container's `stopTimeout`: "The valid values for Fargate are 2-120 seconds", default 30
  ([ContainerDefinition](https://docs.aws.amazon.com/AmazonECS/latest/APIReference/API_ContainerDefinition.html),
  read 2026-11-11).
- The target groups' `deregistration_delay.timeout_seconds`: 0 to 3600 seconds, default 300. On the
  network load balancer the module also sets `deregistration_delay.connection_termination.enabled`,
  which is off by default for TCP, so connections still open at the end of the delay are closed
  rather than left to the engine's SIGKILL
  ([TargetGroupAttribute](https://docs.aws.amazon.com/elasticloadbalancing/latest/APIReference/API_TargetGroupAttribute.html),
  read 2026-11-11).

## The database password

The password lives in two places: on the database, and inside the connection URL in the module's
secret. Both are written in the same run, and only when `database_password_version` changes, since
neither the plan nor the state holds the password to compare. Two things can leave them apart:
Terraform replacing the database (a change to `database_name` or `database_username`, with
`deletion_protection` off), or a first apply that failed after it created the database and before it
wrote the secret. The engine then fails to log in. To recover, raise `database_password_version` by
one and apply: the module sets a new password on the database and writes the matching URL. Then
restart the engine (a new deployment of the service) so it reads the new secret. The same step
rotates the password on purpose.

## Destroying it, and the final snapshot

`deletion_protection` is on by default: turn it off and apply before you destroy. A destroy then
takes a final snapshot of the database, named `pathways-<name>-final`, and schedules the module's KMS
key for deletion with the rest. By default the database, its automated backups and that snapshot are
encrypted under the module's key, so once the key's deletion window ends
(`kms_key_deletion_window_days`, 30 days by default, the most AWS allows) the snapshot cannot be
restored, unless you cancel the key's deletion first.

To keep a final snapshot that outlives the module, give `database_kms_key_arn`, a KMS key of your own
that the module does not manage; its key policy must let RDS use it for the role that applies. We
kept the module's own key as the default so that the module works alone and everything it stores is
under one key it scopes to this deployment; the longest window AWS allows is the default for the same
reason. The snapshot's name is fixed, so a second destroy of a module with the same `name` fails
while the first snapshot exists: copy it to a new name, or delete it, first.

## The bucket and SFTP, from the AWS documentation

What the `bucket` and `sftp` submodules do rests on these pages:

- S3 encryption: SSE-KMS with an S3 Bucket Key, which lowers the requests S3 makes to KMS, and
  whose encryption context names the bucket rather than the object
  ([Reducing the cost of SSE-KMS with Amazon S3 Bucket Keys](https://docs.aws.amazon.com/AmazonS3/latest/userguide/bucket-key.html)).
- S3 public access: the four Block Public Access settings
  ([Blocking public access to your Amazon S3 storage](https://docs.aws.amazon.com/AmazonS3/latest/userguide/access-control-block-public-access.html)),
  and ACLs off with `BucketOwnerEnforced`
  ([Controlling ownership of objects and disabling ACLs](https://docs.aws.amazon.com/AmazonS3/latest/userguide/about-object-ownership.html)).
- TLS only: a bucket policy denying requests where `aws:SecureTransport` is false, and with
  `s3:TlsVersion` below 1.2
  ([Security best practices for Amazon S3](https://docs.aws.amazon.com/AmazonS3/latest/userguide/security-best-practices.html)).
- Server access logs: delivered by `logging.s3.amazonaws.com`, granted in the log bucket's policy
  with `aws:SourceArn` and `aws:SourceAccount`, to a log bucket whose default encryption is SSE-S3,
  since a customer managed key is not supported there
  ([Enabling Amazon S3 server access logging](https://docs.aws.amazon.com/AmazonS3/latest/userguide/enable-server-access-logging.html)).
- Versioning and lifecycle: a deleted object in a versioned bucket stays as a noncurrent version
  until a lifecycle rule expires it
  ([Managing the lifecycle of objects](https://docs.aws.amazon.com/AmazonS3/latest/userguide/object-lifecycle-mgmt.html)).
- Transfer Family endpoint: a VPC endpoint with no Elastic IP is internal, reachable from the VPC
  and what is connected to it, and its security group decides who may connect
  ([Create a server in a virtual private cloud](https://docs.aws.amazon.com/transfer/latest/userguide/create-server-in-vpc.html)).
- Users: service managed users with SSH public keys, a role Transfer Family assumes for each, and a
  logical home directory that maps `/` to the user's prefix and keeps the user inside it
  ([Working with service-managed users](https://docs.aws.amazon.com/transfer/latest/userguide/service-managed-users.html),
  [Using logical directories to simplify your Transfer Family directory structures](https://docs.aws.amazon.com/transfer/latest/userguide/logical-dir-mappings.html)),
  and the confused deputy conditions `aws:SourceAccount` and `aws:SourceArn` on that role's trust
  ([Cross-service confused deputy prevention](https://docs.aws.amazon.com/transfer/latest/userguide/confused-deputy.html)).
- Logs: structured JSON logs to a CloudWatch log group
  ([Logging activity with CloudWatch](https://docs.aws.amazon.com/transfer/latest/userguide/structured-logging.html)),
  and the security policies that set the SSH algorithms
  ([Security policies for AWS Transfer Family servers](https://docs.aws.amazon.com/transfer/latest/userguide/security-policies.html)).

## What it costs each month

We give the drivers, not prices: AWS sets those per region and changes them. Check each against the
[AWS Pricing Calculator](https://calculator.aws/) for your region.

- **The engine**: Fargate bills each task's vCPU and memory per second it runs (`cpu`, `memory`). One
  engine runs all month, and the migrate task for a few minutes a deploy.
- **The database**: RDS bills the instance class per hour (`database_instance_class`), twice over with
  `database_multi_az`, the storage allocated per GB-month (up to `database_max_allocated_storage`),
  and backups beyond the database's own size.
- **The load balancers**: each bills per hour it exists and per load balancer capacity unit, which
  grows with new connections, active connections and bytes. Each exists only with a source of its
  kind.
- **NAT and data transfer**: tasks in private subnets reach AWS APIs through your NAT gateway, which
  bills per hour and per GB processed, unless you add VPC endpoints (which bill per hour and per GB
  too). Data leaving AWS bills per GB.
- **Secrets, the key and the logs**: Secrets Manager per secret per month and per 10,000 calls; KMS per
  key per month and per request; CloudWatch Logs per GB ingested and per GB-month stored, under
  `log_retention_days`.
- **The bucket**, with `bucket_enabled`: S3 bills per GB-month stored, noncurrent versions included
  until `bucket_lifecycle_rules` removes them, and per request. A file source lists its prefix every
  `pollInterval`, so the list requests run all month even when no file arrives. The access logs are
  objects in the log bucket, billed the same way. The Bucket Key keeps KMS requests low.
- **SFTP**, with `sftp_enabled`: Transfer Family bills per hour for each protocol enabled on a server,
  from creation until deletion, whether or not anyone connects, and per GB uploaded and downloaded.
  That hourly charge is often the largest line for a small deployment: turn SFTP off when no
  partner needs it.

## Not here yet

- **Alarms.** CloudWatch alarms on the engine's own metrics, through a collector sidecar, come once
  the engine publishes its metric names.
- **A standby.** Pathways can run a second engine as a standby that takes over the lease. On ECS that
  needs care: ECS replaces a task its load balancer reports unhealthy, and a standby is not ready by
  design. It comes with its own tests.
- **SFTP from the internet.** The SFTP endpoint is internal: partners reach it over your VPN or
  another private link. An internet-facing endpoint needs Elastic IPs, which the module does not
  create yet.
- **A registry release.** No version is tagged or published yet. The
  [Terraform Registry](https://developer.hashicorp.com/terraform/registry/modules/publish) (read
  2026-11-11) publishes only a public GitHub repository named `terraform-<provider>-<name>`, which
  this name fits, and takes release tags that are a semantic version, optionally prefixed with `v`.
  The OpenTofu registry takes a module through its GitHub issue form; its naming and tag rules we
  have not confirmed yet.

## Security scanning

`scripts/policy.sh` runs tflint with the AWS ruleset and `trivy config` at HIGH and CRITICAL. Two
findings are accepted, inline where they fire:

| Check | Where | Why |
| --- | --- | --- |
| `AVD-AWS-0104` (egress to any address) | `modules/security_groups/main.tf`, `aws_vpc_security_group_egress_rule.engine` | The default `egress_rules` allow HTTPS anywhere, which a task needs to reach the image registry, Secrets Manager and CloudWatch Logs through a NAT gateway. With VPC endpoints for those, narrow `egress_rules`. |
| tflint `terraform_unused_required_providers` | `versions.tf`, `aws` and `random` | The root holds no resource of its own; its submodules inherit these providers from it. The root keeps the declarations because they are the constraints a caller reads, and because `terraform test` hands a mocked provider only to a root module that requires it. |

## Compliance

Running Pathways in your account keeps messages in your account. We sign Business Associate
Agreements. Your deployment also needs your own Business Associate Addendum with AWS, which AWS
offers through AWS Artifact, and it covers only the services AWS lists as eligible: check that list
for each service the module uses (ECS on Fargate, RDS, S3, Transfer Family, KMS, Secrets Manager,
CloudWatch Logs, Elastic Load Balancing). A module cannot make a deployment compliant on its own:
what you run on it, who can reach it and how you operate it are yours to decide.

## License

MIT. See [LICENSE](LICENSE).
