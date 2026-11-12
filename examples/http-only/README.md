# http-only

Every source is HTTPS, behind one internal application load balancer.

## What it builds

In an existing VPC, with a NAT gateway you already have:

- one engine on ECS Fargate, 1 vCPU and 2 GiB, and the migrate task definition;
- PostgreSQL on RDS, Multi-AZ, `db.t4g.medium`, with deletion protection on (the module's defaults);
- one internal application load balancer with an HTTPS listener on 8443, presenting your ACM
  certificate under the `ELBSecurityPolicy-TLS13-1-2-2021-06` policy, dropping invalid headers, and
  forwarding to the engine over HTTPS. No network load balancer;
- the KMS key, the secret, the log groups, the security groups and the roles;
- the one channel in [`project/`](project): JSON orders over HTTPS in, checked against a bearer token
  from Secrets Manager, and posted on to the lab's API over HTTPS.

## When to choose it

When your senders speak HTTP: FHIR, JSON or XML APIs, webhooks, or HL7 v2 over HTTP. The load
balancer gives you an ACM certificate that renews on its own and a TLS policy AWS maintains, in front
of an engine that also serves TLS, so nothing is in the clear on either hop.

## What it costs

We give what bills, not prices: AWS sets those per region and changes them.

- Fargate, per second, for 1 vCPU and 2 GiB, all month.
- The database instance per hour, twice over for Multi-AZ; storage per GB-month, twice over.
- One application load balancer per hour and per load balancer capacity unit, which grows with new
  connections, active connections, bytes and rule evaluations.
- The KMS key, the two secrets, and CloudWatch Logs per GB ingested and stored.
- Your NAT gateway, per GB the tasks send through it, the lab's API calls included.

## What it does not cover

- MLLP sources: see [`mllp-only`](../mllp-only), or add `mllp_sources`.
- The DNS name: create an alias record for the name on your certificate, pointing at
  `alb_dns_name`.
- An internet-facing listener. `load_balancer_internal = false` with public subnets makes one, and
  then `allowed_cidr_blocks` is all that stands between the internet and your listener: keep it to
  your senders' addresses. This example keeps it internal.
- A web application firewall, mutual TLS at the load balancer, and the load balancer's access logs.

## Use it

Every value in [`variables.tf`](variables.tf) is a placeholder. Request or import the certificate in
ACM, store the bearer token in a secret, copy `project/` into a project `pathways init` made, add the
RDS global bundle and the source's certificate and key under `certs/`, build the image and push it,
set the variables, then plan and apply from your own pipeline with your own credentials. CI here
validates this directory and tests it against mocked providers (`tests/example-http-only`); nothing in
this repository applies it.
