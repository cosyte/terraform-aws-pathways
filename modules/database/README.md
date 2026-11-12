# database

PostgreSQL on RDS for a Pathways deployment: one instance, Multi-AZ by default, its storage
encrypted, not publicly accessible, and refusing any connection without TLS (`rds.force_ssl`). The
password is generated and written without ever entering the plan or the state, into a Secrets
Manager secret holding the connection URL. Raise `password_version` to set a new one. Performance
Insights and the log exports stay off: they keep statement text.

The root module calls it, and it can be used on its own:

```hcl
module "pathways_database" {
  source = "github.com/cosyte/terraform-aws-pathways//modules/database"

  name               = "integration"
  subnet_ids         = ["subnet-0a1b2c3d4e5f60718", "subnet-0f1e2d3c4b5a60718"]
  security_group_ids = [module.pathways_security_groups.database_security_group_id]
  kms_key_arn        = module.pathways_kms.key_arn
}
```

It needs the `aws` and `random` providers and Terraform 1.11 or later, for write-only arguments.
Inputs are in [`variables.tf`](variables.tf), outputs in [`outputs.tf`](outputs.tf).
