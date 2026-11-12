---
id: module-sftp
title: The sftp submodule
sidebar_label: sftp
description: "Every input and output of modules/sftp, generated from its code."
---

# The sftp submodule

`modules/sftp` holds the optional Transfer Family SFTP server, its users and its logs. The root module calls it; to use it on its own, set `source = "github.com/cosyte/terraform-aws-pathways//modules/sftp"`.

This page is generated from the code by `scripts/docs.sh`, and CI fails when it no longer matches, so it lists every input and output there is. Edit the descriptions in the `.tf` files, never here.

## Required inputs

### name

Name of the deployment. The security group is pathways-\<name\>-sftp, and the roles start pathways-\<name\>-sftp-.

Type: `string`

Required: it has no default.

### vpc_id

The VPC the SFTP endpoint is in.

Type: `string`

Required: it has no default.

### subnet_ids

Subnets for the SFTP endpoint, one network interface in each. Private subnets keep it internal: the module gives it no Elastic IP.

Type: `list(string)`

Required: it has no default.

### allowed_cidr_blocks

The networks allowed to connect to the SFTP endpoint, on port 22: your partners' addresses, or your VPN's. There is no default, and 0.0.0.0/0 is refused, so nothing is open until you name who may connect.

Type: `list(string)`

Required: it has no default.

### bucket_name

Name of the S3 bucket the users' home prefixes are in, such as the bucket submodule's bucket_name.

Type: `string`

Required: it has no default.

### kms_key_arn

ARN of the customer managed KMS key that encrypts the log group and the bucket's objects. The users' roles may use it through S3 alone, and the key's policy must let CloudWatch Logs use it for log_group_name.

Type: `string`

Required: it has no default.

### log_group_name

Name of the CloudWatch log group the server writes its structured logs to. The key's policy must let CloudWatch Logs use the key for it.

Type: `string`

Required: it has no default.

## Optional inputs

### users

The SFTP users, by user name, each with its SSH public keys (one OpenSSH public key per entry: ssh-ed25519, ecdsa-sha2-nistp256, -384 or -521, or ssh-rsa) and the prefix in the bucket that is its home, such as partners/lab. A user sees its prefix as / and reaches nothing outside it. Users are service managed: no password, keys only.

Type:

```hcl
map(object({
    public_keys = list(string)
    home_prefix = string
  }))
```

Default: `{}`

### security_policy_name

The Transfer Family security policy, which sets the SSH ciphers, key exchanges and MACs the server offers.

Type: `string`

Default: `"TransferSecurityPolicy-2024-01"`

### log_retention_days

How many days CloudWatch Logs keeps the server's logs. They name users, files and addresses, never a file's content.

Type: `number`

Default: `365`

### tags

Tags added to every resource the submodule creates. The caller's provider default_tags apply as well.

Type: `map(string)`

Default: `{}`

## Outputs

### server_id

ID of the Transfer Family server.

### server_arn

ARN of the Transfer Family server.

### endpoint

The server's own hostname, s-\<id\>.server.transfer.\<region\>.amazonaws.com.

### vpc_endpoint_id

ID of the server's VPC endpoint. Its DNS names and private addresses are where SFTP clients inside the VPC connect.

### security_group_id

ID of the endpoint's security group, which admits allowed_cidr_blocks on port 22 only.

### log_group_name

Name of the server's CloudWatch log group.

### user_role_arns

ARN of each user's role, by user name: it reaches the user's home prefix alone.
