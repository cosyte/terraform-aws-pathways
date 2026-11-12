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

With `metrics_collector` (the root module sets it when `alarms_enabled` is true), the engine's task
also runs a metrics collector beside the engine: not essential, so the engine runs on if it stops,
with no port mapped. It reads its configuration from `PATHWAYS_COLLECTOR_CONFIG`
(`--config=env:PATHWAYS_COLLECTOR_CONFIG`) and the health endpoint's token from the secret given,
which the engine also gets as `PATHWAYS_HEALTH_TOKEN`; the migrate task does not. It logs to the
engine's log group under the stream prefix `metrics-collector`. Without it, the task definition is
the engine container alone, as it always was.

The execution role must be allowed to read each secret in `secrets`, and the token's secret, as the
`iam` module's is when the root module gives it both. Inputs
are in [`variables.tf`](variables.tf), outputs in [`outputs.tf`](outputs.tf).
