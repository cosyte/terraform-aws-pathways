---
id: upgrade
title: Upgrade Pathways and the module
sidebar_label: Upgrade
description: "Ship a new image of your project, with the schema moved first by the migrate task, and move to a new version of the module."
---

# Upgrade Pathways and the module

Two things change on their own schedules: your project's image, which carries the Pathways version
and your channels, and the version of this module.

## Ship a new image

A deploy is a new image digest. The engine starts with `--no-migrate`, so the schema moves first,
through the migrate task. ECS RunTask cannot change a task's image, so the migrate task definition
has its own image, `migrate_image`. Your CI does three steps, with no Terraform provisioner:

1. Apply with `migrate_image` set to the new image and `image` unchanged. Only the migrate task
   definition gets a new revision.
2. Run it, wait for it to stop, and check it exited 0:

   ```sh
   task=$(aws ecs run-task --cluster "$CLUSTER" --launch-type FARGATE \
     --task-definition "$MIGRATE_TASK_DEFINITION_ARN" \
     --network-configuration "$MIGRATE_NETWORK_CONFIGURATION" \
     --query 'tasks[0].taskArn' --output text)
   aws ecs wait tasks-stopped --cluster "$CLUSTER" --tasks "$task"
   code=$(aws ecs describe-tasks --cluster "$CLUSTER" --tasks "$task" \
     --query 'tasks[0].containers[0].exitCode' --output text)
   test "$code" = "0"
   ```

   The values come from the outputs `cluster_name`, `migrate_task_definition_arn` and
   `migrate_network_configuration`. The CI role needs `ecs:RunTask`, `ecs:DescribeTasks` and
   `iam:PassRole` on `execution_role_arn` and `task_role_arn`.
3. Apply with `image` set to the new image, and `migrate_image` back to null. The service replaces
   the engine.

`pathways migrate` applies expand steps only, which the running engine works on, so steps 1 and 2
are safe while the old engine runs. A contract step waits for `pathways migrate --contract`, which
is yours to run once every engine is on the new version. The Pathways docs cover schema steps in
[Upgrade Pathways](https://docs.cosyte.com/pathways/upgrade-pathways).

## What a deploy does to traffic

The service runs one engine: the engine lease refuses a second on the same database. A deploy stops
the old task before it starts the new one, so there is a gap of one engine start, which your senders
must retry across.

When ECS stops the engine it deregisters it from the load balancers, which wait
`drain_timeout_seconds` for open connections and then close them. ECS then sends SIGTERM: the engine
turns not ready, closes its sources and finishes what it is storing, and gets `drain_timeout_seconds`
again before SIGKILL. The input takes 2 to 120 seconds, 60 by default: Fargate allows a stop timeout
of at most 120 seconds.

## Move to a new version of the module

Each release of the module is a tag, `v` and a semantic version, with its changes in `CHANGELOG.md`
and on the release's page. To move:

1. Read the changelog entries between your version and the new one. A change that asks something of
   you says what.
2. Change the `ref` in your module's `source` to the new tag, and run `terraform init -upgrade`.
3. Run `terraform plan` and read it before you apply. Look for any resource Terraform would replace
   rather than update: a replaced database is a new, empty database, and a replaced key cannot read
   what the old one encrypted. `deletion_protection`, on by default, stops a replacement of the
   database and the load balancers at apply.
4. Apply, from your own pipeline.

Until the first release is tagged, `ref` names a commit, and the same steps apply.

## Related

- [Destroy a deployment](./destroy-a-deployment.md).
- `image`, `migrate_image` and `drain_timeout_seconds` in
  [Inputs and outputs](./inputs-and-outputs.md#migrate_image).
