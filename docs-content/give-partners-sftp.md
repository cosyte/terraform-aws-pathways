---
id: give-partners-sftp
title: Give partners SFTP
sidebar_label: Give partners SFTP
description: "Put an internal AWS Transfer Family SFTP server in front of the bucket, with SSH key users each locked to their own prefix."
---

# Give partners SFTP

A partner that drops and picks up files over SFTP gets a user on an AWS Transfer Family server in
front of the module's bucket. Each user sees only its own prefix of the bucket, and a channel reads
and writes the same prefix through the bucket.

## Turn it on

SFTP needs the bucket. Name the networks that may connect, and one user per partner:

```hcl title="main.tf"
module "pathways" {
  source = "github.com/cosyte/terraform-aws-pathways?ref=<commit or tag>"
  # ...the inputs you already set

  bucket_enabled = true

  sftp_enabled             = true
  sftp_allowed_cidr_blocks = ["10.30.0.0/24"]
  sftp_users = {
    lab = {
      public_keys = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA lab-key"]
      home_prefix = "partners/lab"
    }
  }
}
```

The key above is a placeholder: give each partner's own public key, one OpenSSH line. Users sign in
with a key, never a password, and a private key is refused.

## Wire a channel to the user's prefix

The user `lab` sees `partners/lab` as `/`. A channel that writes to `partners/lab/outbox` in the
bucket puts files where the lab sees `/outbox`:

```yaml title="channels/adt-to-lab/channel.yaml"
destinations:
  - file:
      dir: partners/lab/outbox
      s3:
        bucket: { env: PATHWAYS_BUCKET }
```

For files the partner sends, point a file source at a prefix under its home, such as
`partners/lab/inbox`.

## How partners reach it

The server's endpoint is a VPC endpoint with no Elastic IP: it is internal to your VPC, reachable on
port 22 from `sftp_allowed_cidr_blocks` alone. `0.0.0.0/0`, and any other `/0` block, is refused.
Partners connect over your VPN or another private link, to the endpoint's DNS names or private
addresses: the `sftp_vpc_endpoint_id` output names the endpoint. `sftp_subnet_ids` places it in
other subnets than the engine's.

An internet-facing endpoint needs Elastic IPs, which the module does not create yet.

## What each user can do

- List, read, write and delete under its `home_prefix`, through a role of its own that reaches that
  prefix alone. A `home_prefix` with `*` or `?`, or with a `.` or `..` segment, is refused.
- Nothing above its prefix: a logical home directory maps `/` to it.
- Only this server, in your account, may assume the users' roles.

The server logs to a CloudWatch log group encrypted under the module's key: the logs name users,
files and addresses, never a file's content. `sftp_security_policy_name` sets the SSH ciphers, key
exchanges and MACs, `TransferSecurityPolicy-2024-01` by default.

## What it costs

Transfer Family bills per hour for each protocol enabled on a server, from creation until deletion,
whether or not anyone connects, and per GB uploaded and downloaded. For a small deployment that hourly
charge is often the largest line: turn SFTP off when no partner needs it.

## Related

- [Turn on the bucket](./turn-on-the-bucket.md).
- [The sftp submodule](./module-sftp.md), and `sftp_users` in
  [Inputs and outputs](./inputs-and-outputs.md#sftp_users).
- The [complete example](./example-complete.md) does all of this for one partner.
