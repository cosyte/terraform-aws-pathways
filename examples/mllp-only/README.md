# mllp-only

Every source is HL7 v2 over MLLP, behind one internal network load balancer.

## What it builds

In an existing VPC, with a NAT gateway you already have:

- one engine on ECS Fargate, 1 vCPU and 2 GiB, and the migrate task definition;
- PostgreSQL on RDS, Multi-AZ, `db.t4g.medium`, with deletion protection on (the module's defaults);
- one internal network load balancer with two TCP listeners, 2575 for ADT and 2577 for results,
  each passed straight through to the engine, which terminates its own TLS. Both are open to the
  hospital's and the lab's networks;
- no application load balancer, no ACM certificate, no bucket and no SFTP;
- the KMS key, the secret, the log groups, the security groups and the roles;
- the two channels in [`project/`](project): ADT from the hospital to the lab on 2576, and results
  from the lab to the EHR on 2578, each destination allowed in `egress_rules` and nowhere else.

## When to choose it

When your interfaces are HL7 v2 over MLLP, which is most hospital ADT, orders and results feeds.
TLS ends in the engine, so the certificates and keys are in your image and the load balancer never
sees a message in the clear.

## What it costs

We give what bills, not prices: AWS sets those per region and changes them.

- Fargate, per second, for 1 vCPU and 2 GiB, all month.
- The database instance per hour, twice over for Multi-AZ; storage per GB-month, twice over.
- One network load balancer per hour and per capacity unit, which grows with new connections, active
  connections and bytes: long-lived MLLP connections count as active all month. A second listener
  adds no hourly charge.
- The KMS key, the secret, and CloudWatch Logs per GB ingested and stored.
- Your NAT gateway, per GB the tasks send through it.

## What it does not cover

- HTTP sources: see [`http-only`](../http-only), or add `http_sources` and a certificate.
- One network per listener: `allowed_cidr_blocks` opens every MLLP listener to every network in it.
  To keep the lab off the ADT port, narrow each sender with your network's own rules, or run two
  deployments.
- More than five sources: an ECS service attaches to at most five target groups, one per source, so
  the module refuses a sixth.
- An internet-facing listener. Partners reach this one over your VPN or another private link.

## Use it

Every value in [`variables.tf`](variables.tf) is a placeholder. Copy `project/` into a project
`pathways init` made, add the RDS global bundle, the MLLP sources' certificate and key and the lab's
and EHR's CAs under `certs/`, build the image and push it, set the variables, then plan and apply
from your own pipeline with your own credentials. CI here validates this directory and tests it
against mocked providers (`tests/example-mllp-only`); nothing in this repository applies it.
