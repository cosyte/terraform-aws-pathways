# multiple-active-nodes

**Not yet supported.** This folder holds no Terraform on purpose: the shape it names cannot run
safely yet, and we will not ship an example that deploys it.

## What it would build

Several engines, all active at once, sharing one PostgreSQL database, each taking part of the
traffic behind the load balancers, so the deployment grows past one task's CPU and memory and loses
no capacity when one task stops.

## What it waits on

**Pathways running several active engines on one database.** Today the engine takes one engine lease
per database: a second engine started against the same database is refused, or, with
`pathways start --standby`, waits without taking any traffic until the first stops. Every write an
engine makes carries its lease's epoch, so two engines can never both deliver the same message. Several
active engines need the engine to share the work between them, with that same guarantee, and that
is not in a released Pathways yet.

Once it is, this folder gets the example, written to the engine's design and tested here like the
others. Until then, a service with more than one task would only have the second refused, so the
module runs one (`desired_count` of 1), and it has no input to change that.

## What to use today

- [`production`](../production): one engine, sized up with `cpu` and `memory`, and the database's
  Multi-AZ standby. ECS replaces the engine if it stops.
- Several deployments, each with its own channels and its own database, if one engine's size is not
  enough.

## What it costs

Nothing: there is nothing here to deploy.

## What it does not cover

Everything, until the engine supports it.
