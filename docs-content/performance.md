---
id: performance
title: Performance
sidebar_label: Performance
description: "What sets the throughput of a deployment, how to size the engine and the database, and why the module itself has no benchmark."
---

# Performance

The module is infrastructure code: it creates resources and runs nothing itself. How fast a
deployment moves messages is how fast the engine runs on the size of task and database you give it,
so the numbers that matter are the engine's, which the
[Pathways performance page](https://docs.cosyte.com/pathways/performance) gives with its method.

## What sets the throughput

- **The engine's task size**, `cpu` and `memory`: one engine runs per database, so a deployment scales
  up, not out. Fargate allows only some memory sizes for each CPU size; AWS refuses the task
  definition otherwise.
- **The database**, `database_instance_class` and its storage: every message is stored before its
  sender is acknowledged, so the database's write latency bounds how fast a source can acknowledge.
- **The network path**: the load balancers pass traffic to the engine in your private subnets, and
  the engine reaches the AWS APIs through your NAT gateway or VPC endpoints.

## How to measure your own

Run the engine's benchmarks, as its performance page describes, on the task size you chose, and
watch the service's CPU and memory in CloudWatch while you send synthetic traffic through the load
balancers. Container Insights (`container_insights`) adds per-task metrics, at a cost.

## Current numbers

The numbers for this section are measured on `main` at each release and filled in when the release
is built. They are never typed by hand.
