# sftp

An AWS Transfer Family SFTP server in front of an S3 bucket, for partners who drop files for a
Pathways file source to read, or pick up what a file destination wrote. The root module calls it
when `sftp_enabled` is true, on the bucket submodule's bucket.

- **Internal**: a VPC endpoint in `subnet_ids`, with no Elastic IP, so it is reachable only from
  inside the VPC and the networks connected to it.
- **Named networks only**: its security group admits `allowed_cidr_blocks` on TCP 22 and nothing
  else. There is no default, and `0.0.0.0/0` (any `/0`) is refused.
- **SFTP only**, with the security policy `security_policy_name` (`TransferSecurityPolicy-2024-01`
  by default) setting the ciphers, key exchanges and MACs.
- **Users** are service managed and sign in with the SSH public keys you give, never a password.
  Each is locked to its `home_prefix` twice: a logical home directory maps `/` to the prefix, so the
  user sees nothing above it, and the user's own role lists, reads, writes and deletes under that
  prefix alone. A `home_prefix` with `*` or `?`, which that role policy would read as wildcards, or
  with a `.` or `..` segment, is refused. Only this server, in your account, may assume those roles.
- **Logs**: structured JSON logs to a CloudWatch log group, encrypted under your key and kept for
  `log_retention_days`. They name users, files and addresses, never a file's content.

```hcl
module "pathways_sftp" {
  source = "github.com/cosyte/terraform-aws-pathways//modules/sftp"

  name                = "integration"
  vpc_id              = "vpc-0a1b2c3d4e5f60718"
  subnet_ids          = ["subnet-0a1b2c3d4e5f60718", "subnet-0f1e2d3c4b5a60718"]
  allowed_cidr_blocks = ["10.30.0.0/24"]
  bucket_name         = module.pathways_bucket.bucket_name
  kms_key_arn         = module.pathways_kms.key_arn
  log_group_name      = "/pathways/integration/sftp"

  users = {
    lab = {
      public_keys = ["ssh-ed25519 AAAA... lab-key"]
      home_prefix = "partners/lab"
    }
  }
}
```

The key's policy must let CloudWatch Logs use it for `log_group_name`; the kms submodule's allows
every group under its `log_group_prefix`. It has no provider block: your `aws` provider and its
region apply. Inputs are in [`variables.tf`](variables.tf), outputs in [`outputs.tf`](outputs.tf).
