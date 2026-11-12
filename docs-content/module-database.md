---
id: module-database
title: The database submodule
sidebar_label: database
description: "Every input and output of modules/database, generated from its code."
---

# The database submodule

`modules/database` holds PostgreSQL on RDS and the secret holding its URL. The root module calls it; to use it on its own, set `source = "github.com/cosyte/terraform-aws-pathways//modules/database"`.

This page is generated from the code by `scripts/docs.sh`, and CI fails when it no longer matches, so it lists every input and output there is. Edit the descriptions in the `.tf` files, never here.

## Required inputs

### name

Name of the deployment. The instance, its subnet group, its parameter group, its final snapshot and its secret are named from it.

Type: `string`

Required: it has no default.

### subnet_ids

Subnets for the database, in at least two availability zones.

Type: `list(string)`

Required: it has no default.

### security_group_ids

The security groups of the database. Only what they admit reaches it.

Type: `list(string)`

Required: it has no default.

### kms_key_arn

ARN of the customer managed KMS key that encrypts the connection URL secret, and the storage too unless storage_kms_key_arn is given.

Type: `string`

Required: it has no default.

## Optional inputs

### storage_kms_key_arn

ARN of a KMS key that encrypts the database's storage, its automated backups and its final snapshot instead of kms_key_arn, so the snapshot can outlive that key. Null uses kms_key_arn. Its key policy must let RDS use it for the role that applies.

Type: `string`

Default: `null`

### engine_version

The PostgreSQL version of the RDS instance, a major version such as 17, or a full one.

Type: `string`

Default: `"17"`

### parameter_group_family

The parameter group family matching engine_version, such as postgres17.

Type: `string`

Default: `"postgres17"`

### instance_class

The RDS instance class of the database.

Type: `string`

Default: `"db.t4g.medium"`

### allocated_storage

The database's starting storage, in GiB.

Type: `number`

Default: `50`

### max_allocated_storage

The most storage, in GiB, RDS may grow the database to on its own. Equal to allocated_storage turns that off.

Type: `number`

Default: `200`

### multi_az

Whether RDS keeps a standby copy of the database in a second availability zone and fails over to it.

Type: `bool`

Default: `true`

### backup_retention_days

How many days RDS keeps automated backups of the database.

Type: `number`

Default: `14`

### database_name

The name of the database Pathways stores messages in.

Type: `string`

Default: `"pathways"`

### username

The database's master user, which Pathways connects as.

Type: `string`

Default: `"pathways"`

### password_version

Raise this by one to set a new password: the module generates one, sets it on the database and writes the new connection URL to its secret in the same run, and neither the plan nor the state ever holds it.

Type: `number`

Default: `1`

### deletion_protection

Whether the database refuses deletion. Turn it off, and apply, before you destroy the module.

Type: `bool`

Default: `true`

### tags

Tags added to every resource the module creates. The caller's provider default_tags apply as well.

Type: `map(string)`

Default: `{}`

## Outputs

### address

Hostname of the PostgreSQL instance. Connections must use TLS, verified against the RDS certificate authority.

### port

Port of the PostgreSQL instance.

### instance_arn

ARN of the RDS instance.

### storage_kms_key_arn

ARN of the KMS key that encrypts the database's storage, its backups and its final snapshot.

### url_secret_arn

ARN of the Secrets Manager secret holding the connection URL, password inside.
