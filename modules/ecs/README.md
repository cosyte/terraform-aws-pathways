# ecs

The ECS cluster of a Pathways deployment, its two Fargate task definitions and its service. The
engine task runs `pathways start --no-migrate`; the migrate task definition runs `pathways migrate`
on its own image, `migrate_image`, for your CI to run with ECS RunTask before a deploy. The service
runs one engine in private subnets with no public address, stops the old task before it starts the
new one, and has ECS Exec off. The container health check runs `pathways probe`, which asks `/livez`.

The root module calls it, and it can be used on its own:

```hcl
module "pathways_ecs" {
  source = "github.com/cosyte/terraform-aws-pathways//modules/ecs"

  name                   = "integration"
  image                  = "123456789012.dkr.ecr.us-east-1.amazonaws.com/integration@sha256:<digest>"
  container_ports        = [2575, 9091]
  execution_role_arn     = module.pathways_iam.execution_role_arn
  task_role_arn          = module.pathways_iam.task_role_arn
  engine_log_group_name  = module.pathways_logs.engine_log_group_name
  migrate_log_group_name = module.pathways_logs.migrate_log_group_name
  subnet_ids             = ["subnet-0a1b2c3d4e5f60718", "subnet-0f1e2d3c4b5a60718"]
  security_group_ids     = [module.pathways_security_groups.engine_security_group_id]

  load_balancers = {
    adt = { target_group_arn = module.pathways_load_balancers.mllp_target_group_arns["adt"], container_port = 2575 }
  }
}
```

The execution role must be allowed to read each secret in `secrets`, as the `iam` module's is. Inputs
are in [`variables.tf`](variables.tf), outputs in [`outputs.tf`](outputs.tf).
