# logs

The two CloudWatch log groups of a Pathways deployment, `<prefix>/engine` and `<prefix>/migrate`,
encrypted under a customer managed key and kept for `retention_days`. They get the engine's own JSON
lines, which hold ids, counts and codes and never a message's content.

The root module calls it, and it can be used on its own:

```hcl
module "pathways_logs" {
  source = "github.com/cosyte/terraform-aws-pathways//modules/logs"

  log_group_prefix = "/pathways/integration"
  kms_key_arn      = module.pathways_kms.key_arn
}
```

The key's policy must let CloudWatch Logs use it for log groups under the prefix, as the `kms`
module's does. Inputs are in [`variables.tf`](variables.tf), outputs in [`outputs.tf`](outputs.tf).
