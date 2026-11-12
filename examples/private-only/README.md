# private-only

Nothing reachable from the internet, and nothing reaching out to it: no public ingress, and no NAT
gateway.

## What it builds

In an existing VPC whose engine subnets route to no internet gateway and no NAT gateway:

- one engine on ECS Fargate, 1 vCPU and 2 GiB, with no public address, and the migrate task
  definition;
- PostgreSQL on RDS, Multi-AZ, `db.t4g.medium`, not publicly accessible, with deletion protection on
  (the module's defaults);
- an internal network load balancer with one MLLP listener, which resolves to private addresses
  only;
- VPC interface endpoints for `ecr.api`, `ecr.dkr`, `secretsmanager` and `logs`, with private DNS,
  behind a security group that admits the engine alone on 443, and an S3 gateway endpoint for the
  image's layers;
- the engine's egress narrowed to the VPC's own network on 443 (the endpoints), S3's prefix list on
  443 (the gateway endpoint), and the lab's network on 2576. No rule reaches `0.0.0.0/0`;
- the KMS key, the secret, the log groups, the security groups and the roles;
- the one channel in [`project/`](project): ADT over MLLP in, admissions over MLLP out to the lab.

## When to choose it

When your security policy says the integration engine has no path to or from the internet. Senders
and destinations reach it over your private network: a VPN, Direct Connect, a transit gateway or
peering.

## What it costs

We give what bills, not prices: AWS sets those per region and changes them.

- Four interface endpoints, each per hour in each availability zone it is in (two here), and per GB
  processed. Price them against the NAT gateway they replace, which bills per hour and per GB too;
  you choose this shape for its isolation, not its price.
- The S3 gateway endpoint: no hourly or per GB charge.
- Fargate, per second, for 1 vCPU and 2 GiB, all month.
- The database instance per hour, twice over for Multi-AZ; storage per GB-month, twice over.
- The network load balancer per hour and per capacity unit.
- The KMS key, the secret, and CloudWatch Logs per GB ingested and stored.

## What it does not cover

- A destination on the internet: an HTTPS API outside your network needs a NAT gateway or a proxy,
  and an `egress_rules` entry for it. That is no longer this shape.
- An image in another registry: with no NAT gateway the task reaches ECR in its own region alone.
  Copy the image there first.
- The bucket or SFTP: with `bucket_enabled` the engine reaches the bucket through the same S3 gateway
  endpoint; SFTP's endpoint is internal already. Neither is in this example.
- Secrets in SSM Parameter Store, or a customer managed key the task must call: add the `ssm` or
  `kms` interface endpoint.
- Route tables, network ACLs and DNS resolution for your private network: those are your network's.

## Use it

Every value in [`variables.tf`](variables.tf) is a placeholder. Copy `project/` into a project
`pathways init` made, add the RDS global bundle, the MLLP source's certificate and key and the lab's
CA under `certs/`, build the image and push it to ECR in the same region, set the variables, then plan
and apply from your own pipeline with your own credentials. CI here validates this directory and
tests it against mocked providers (`tests/example-private-only`); nothing in this repository applies
it.
