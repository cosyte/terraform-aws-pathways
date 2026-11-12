---
id: troubleshooting
title: Troubleshooting
sidebar_label: Troubleshooting
description: "What to do when a plan is refused, the engine never turns healthy, it cannot log in to its database, or a destroy fails."
---

# Troubleshooting

## The plan is refused

The module checks its inputs before it plans, and each refusal says what it wants. The ones met most
often:

- **`image must name the image by digest`**: a tag alone is refused, so a deploy always runs exactly
  the image you tested. Look the digest up with `docker buildx imagetools inspect <image>:<tag>` and
  give `registry/repository@sha256:<digest>`.
- **`sftp_enabled needs bucket_enabled`**: the SFTP users' homes are in the module's bucket.
- **`sftp_allowed_cidr_blocks may not hold 0.0.0.0/0`**: name the networks that may connect.
- **`http_sources needs alb_certificate_arn`**: the application load balancer's listeners are HTTPS
  only.
- **At most five sources**: an ECS service attaches to at most five target groups, one per source,
  so `mllp_sources` and `http_sources` together may name at most five.
- **`name must be 2 to 24 characters`**: it prefixes the load balancer and target group names, which
  AWS caps at 32 characters.

## The engine never turns healthy

- **No schema yet.** The engine starts with `--no-migrate` and refuses a database that lacks the
  schema it needs, so ECS keeps replacing it. Run the migrate task, as the
  [Quickstart](./quickstart.md#6-run-the-migrate-task) shows.
- **No probe listener the load balancers reach.** Your `pathways.yaml` needs a `probes` block on
  `probe_port` (9091 by default) with `host: 0.0.0.0`. Without it the engine never turns healthy.
- **The database refuses the connection.** It refuses any connection without TLS, and its
  certificate is signed by the Amazon RDS certificate authority, which Node does not trust by
  default: add the RDS global bundle to your image and name it in `storage.postgres.tls.ca`.
- **A secret cannot be read.** ECS reads each secret in `secrets` when a task starts. If a secret
  uses a customer managed key, list the key in `secrets_kms_key_arns`.
- **The engine cannot reach the AWS APIs.** The tasks need a NAT gateway or VPC endpoints: see
  [Place it in your network](./place-it-in-your-network.md#reach-the-aws-apis).

The stopped task's reason, in `aws ecs describe-tasks`, and the engine's log group,
`engine_log_group_name`, say which.

## The engine cannot log in to its database

The password lives in two places: on the database, and inside the connection URL in the module's
secret. Both are written in the same run, and only when `database_password_version` changes. They
come apart when Terraform replaced the database (a change to `database_name` or
`database_username`, with deletion protection off), or when a first apply failed after it created the
database and before it wrote the secret.

Raise `database_password_version` by one and apply: the module sets a new password on the database
and writes the matching URL. Then start a new deployment of the service, so the engine reads the new
secret. The same step rotates the password on purpose.

## A destroy fails

- **Deletion protection**: set `deletion_protection = false` and apply first.
- **The final snapshot exists**: its name, `pathways-<name>-final`, is fixed, so a second destroy of
  a deployment with the same `name` fails while the first one's snapshot is there. Copy it to a new
  name, or delete it.

See [Destroy a deployment](./destroy-a-deployment.md).

## Senders see a gap during a deploy

The service runs one engine and stops the old one before it starts the new one, so a deploy leaves a
gap of one engine start. Senders must retry across it. See
[Upgrade Pathways and the module](./upgrade.md#what-a-deploy-does-to-traffic).
