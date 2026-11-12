# second-region-disaster-recovery

**Not yet supported.** This folder holds no Terraform on purpose: the shape it names cannot run
safely yet, and we will not ship an example that deploys it.

## What it would build

A second deployment in another region, ready to run: a replica of the database kept current, the
image and the master key there already, and a way to promote the replica and start the engine on it
when the first region fails, in minutes rather than the hour or more a restore takes.

## What it waits on

**Promotion to a second region in Pathways.** The engine lease keeps two engines from delivering the
same message, but only on one database. A promoted replica is a second database: the engine in the
first region, if it is still running behind a network split, would keep delivering from its copy
while the second region delivers from the other, and a destination would get messages twice. Safe
promotion needs the engine to fence the old region off once the new one takes over, and that is not
in a released Pathways yet.

Once it is, this folder gets the example, written to the engine's design and tested here like the
others.

## What to use today

[`cross-region-backup`](../cross-region-backup): the database's automated backups replicated to a
second region, and a restore there by hand, step by step, once you have stopped the first region's
engine.

## What it costs

Nothing: there is nothing here to deploy.

## What it does not cover

Everything, until the engine supports it.
