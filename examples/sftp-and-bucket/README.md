# sftp-and-bucket

Files only: partners exchange files over SFTP, and the engine reads and writes them in the S3 bucket
behind it. No load balancer.

## What it builds

In an existing VPC, with a NAT gateway you already have:

- one engine on ECS Fargate, 1 vCPU and 2 GiB, and the migrate task definition;
- PostgreSQL on RDS, Multi-AZ, `db.t4g.medium`, with deletion protection on (the module's defaults);
- an S3 bucket, encrypted under the module's key with an S3 Bucket Key, versioned, all public access
  blocked, TLS only, with its access log bucket. Its lifecycle rules remove noncurrent versions after
  30 days, unfinished uploads after 7, and what the clinic has not picked up after 30;
- an SFTP server on an internal VPC endpoint, open on port 22 to the partners' networks alone, with
  two users on SSH keys: `lab`, whose home is `partners/lab`, and `clinic`, whose home is
  `partners/clinic`. Each sees its home as `/` and reaches nothing outside it;
- no load balancer: with no MLLP or HTTP source the module creates neither;
- the KMS key, the secret, the log groups (the SFTP server's included), the security groups and the
  roles;
- the one channel in [`project/`](project): each result the lab uploads to `/inbox` is copied to the
  clinic's `/outbox`.

## When to choose it

When your partners send and pick up files rather than holding a connection open: batch results,
claims, rosters, or anything a partner already sends over SFTP. The engine needs no access key: its
task role reaches the bucket.

## What it costs

We give what bills, not prices: AWS sets those per region and changes them.

- The SFTP server per hour for the SFTP protocol, from creation until deletion, whether or not anyone
  connects, and per GB uploaded and downloaded. For a small deployment this is often the largest
  line.
- Fargate, per second, for 1 vCPU and 2 GiB, all month.
- The database instance per hour, twice over for Multi-AZ; storage per GB-month, twice over.
- S3 per GB-month stored, noncurrent versions included until the lifecycle rules remove them, and per
  request. The file source lists its prefix every `pollInterval` (30 seconds here), so its list
  requests run all month even when no file arrives. The access logs are objects in the log bucket.
- The KMS key, the secret, and CloudWatch Logs per GB ingested and stored.
- Your NAT gateway, per GB the tasks send through it.

## What it does not cover

- SFTP from the internet: the endpoint is internal, so partners reach it over your VPN or another
  private link. An internet-facing endpoint needs Elastic IPs, which the module does not create yet.
- Passwords: users sign in with SSH keys only.
- MLLP or HTTP sources: add `mllp_sources` or `http_sources`, as
  [`complete`](../complete) does.
- Telling a partner a file arrived: the partner polls its outbox.

## Use it

Every value in [`variables.tf`](variables.tf) is a placeholder. Copy `project/` into a project
`pathways init` made, add the RDS global bundle under `certs/`, build the image and push it, set the
variables and the partners' SSH public keys, then plan and apply from your own pipeline with your own
credentials. CI here validates this directory and tests it against mocked providers
(`tests/example-sftp-and-bucket`); nothing in this repository applies it.
