# bring-your-own-vpc

Pathways in a VPC your network team already runs, found by its tags, with each tier in its own
subnets.

## What it builds

It reads, and creates none of: the VPC tagged `Name = integration-vpc`, and its subnets tagged
`Tier = app`, `data` and `edge`. In them it builds:

- one engine on ECS Fargate, 1 vCPU and 2 GiB (the module's default), in the `app` subnets;
- PostgreSQL on RDS, Multi-AZ, `db.t4g.medium`, in the `data` subnets (`database_subnet_ids`);
- an internal network load balancer with one MLLP listener, in the `edge` subnets
  (`load_balancer_subnet_ids`);
- the KMS key, the secret, the log groups, the security groups and the roles;
- the one channel in [`project/`](project): ADT over MLLP in, admissions over MLLP out to the lab.

## When to choose it

When the network is not yours to change: a platform team owns the VPC, its routes, its NAT gateway
and its peering, and hands you subnets by tag. Looking them up by tag means a subnet replaced by
that team is picked up on your next plan, with no id to edit.

## What it costs

We give what bills, not prices: AWS sets those per region and changes them.

- Fargate, per second, for 1 vCPU and 2 GiB, all month.
- The database instance per hour, twice over for Multi-AZ; storage per GB-month, twice over; backups
  beyond the database's size.
- The network load balancer per hour and per capacity unit.
- The KMS key, the secret, and CloudWatch Logs per GB ingested and stored.
- The VPC's NAT gateway and its data transfer, which your network team's bill already carries.

## What it does not cover

- Creating the network. The module and this example never create a VPC, a subnet, a route table or
  a NAT gateway. A VPC with no NAT gateway: see [`private-only`](../private-only).
- A tag that matches no subnet, or subnets in one availability zone: the module refuses fewer than
  two subnets for each tier, but cannot tell two subnets in the same zone apart. Tag subnets in two
  zones or more.
- Rules your network team keeps elsewhere, such as network ACLs and firewall routes: open port 2575
  from your senders to the `edge` subnets, and 2576 from the `app` subnets to the lab.

## Use it

Set `vpc_name` and the three tier tags to your own, and the other placeholders in
[`variables.tf`](variables.tf). Copy `project/` into a project `pathways init` made, add the RDS
global bundle, the MLLP source's certificate and key and the lab's CA under `certs/`, build the image
and push it, then plan and apply from your own pipeline with your own credentials. CI here validates
this directory and tests it against mocked providers (`tests/example-bring-your-own-vpc`); nothing
in this repository applies it.
