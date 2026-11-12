---
id: destroy-a-deployment
title: Destroy a deployment
sidebar_label: Destroy a deployment
description: "Turn deletion protection off, destroy the module, and decide what happens to the database's final snapshot and the key that encrypts it."
---

# Destroy a deployment

## Turn deletion protection off

`deletion_protection` is on by default, on the database and the load balancers. Set it to `false`
and apply, then destroy:

```hcl title="main.tf"
  deletion_protection = false
```

```sh
terraform apply
terraform destroy
```

## The final snapshot

A destroy takes a final snapshot of the database, named `pathways-<name>-final`, and schedules the
module's KMS key for deletion with the rest. By default the database, its automated backups and that
snapshot are encrypted under the module's key, so once the key's deletion window ends
(`kms_key_deletion_window_days`, 30 days by default, the most AWS allows) the snapshot cannot be
restored, unless you cancel the key's deletion first.

To keep a final snapshot that outlives the module, give `database_kms_key_arn`, a KMS key of your own
that the module does not manage. Its key policy must let RDS use it for the role that applies.

The snapshot's name is fixed, so a second destroy of a deployment with the same `name` fails while
the first snapshot exists: copy it to a new name, or delete it, first. A snapshot bills per GB-month
until you delete it.

## What stays behind

- The final snapshot, as above.
- The master key's secret and any other secret you passed in `secrets`: they are yours, not the
  module's.
- With Container Insights on, the log group AWS created for it,
  `/aws/ecs/containerinsights/<cluster>/performance`.

## Related

- `deletion_protection`, `database_kms_key_arn` and `kms_key_deletion_window_days` in
  [Inputs and outputs](./inputs-and-outputs.md#deletion_protection).
