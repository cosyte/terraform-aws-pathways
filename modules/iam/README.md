# iam

The two roles of a Pathways deployment's ECS tasks. The execution role is what ECS uses to start a
task: it pulls the image (from its own ECR repository only, when the image is in ECR), reads exactly
the secrets the task injects, decrypts them, and writes the logs. The task role is what the engine
runs as; it has no permissions until you attach some. Only ECS acting for your account may assume
either.

The root module calls it, and it can be used on its own:

```hcl
module "pathways_iam" {
  source = "github.com/cosyte/terraform-aws-pathways//modules/iam"

  name           = "integration"
  images         = ["123456789012.dkr.ecr.us-east-1.amazonaws.com/integration@sha256:<digest>"]
  secrets        = { PATHWAYS_KEY_2026_11 = "arn:aws:secretsmanager:us-east-1:123456789012:secret:integration/master-key-AbCdEf" }
  kms_key_arns   = [module.pathways_kms.key_arn]
  log_group_arns = [module.pathways_logs.engine_log_group_arn, module.pathways_logs.migrate_log_group_arn]
}
```

Inputs are in [`variables.tf`](variables.tf), outputs in [`outputs.tf`](outputs.tf).
