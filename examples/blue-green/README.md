# blue-green

**Not yet supported.** This folder holds no Terraform on purpose: the shape it names cannot run
safely yet, and we will not ship an example that deploys it.

## What it would build

Two engines on one database, the running version (blue) and the next (green). Green starts, is
checked, and then takes over from blue in one handover: blue stops taking messages, finishes what it
holds, and hands the engine lease to green, so a deploy has no gap and can be rolled back by handing
back.

## What it waits on

**A handover between two engines in Pathways.** Today a second engine on the same database waits as
a standby (`pathways start --standby`) and takes the engine lease only once the first has stopped
and its lease has run out: about 20 seconds plus its own start with the default 15-second time to
live. There is no way yet to hand the lease over on purpose, at a moment you choose, and back again.

**A standby engine in this module.** Even a standby needs care on ECS: ECS replaces a task its load
balancer reports unhealthy, and a standby is not ready by design. The module runs one engine until
that has its own design and tests.

Once both are in, this folder gets the example, written to the engine's design and tested here like
the others.

## What to use today

The module's deploy: the migrate task first, then a new image, which ECS starts once the old task
has stopped (minimum healthy 0 %, maximum 100 %). Senders retry across the gap of one engine start.
The [README at the repository root](../../README.md#deploy) and the docs' upgrade guide walk through
it.

## What it costs

Nothing: there is nothing here to deploy.

## What it does not cover

Everything, until the engine supports it.
