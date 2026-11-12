# kms

The customer managed KMS key of a Pathways deployment, with its alias. It rotates every year. The
account administers it through IAM, and CloudWatch Logs may use it only for the log groups under
`log_group_prefix`.

The root module calls it, and it can be used on its own:

```hcl
module "pathways_kms" {
  source = "github.com/cosyte/terraform-aws-pathways//modules/kms"

  name             = "integration"
  log_group_prefix = "/pathways/integration"
}
```

It has no provider block: your `aws` provider and its region apply. Inputs are in
[`variables.tf`](variables.tf), outputs in [`outputs.tf`](outputs.tf).
