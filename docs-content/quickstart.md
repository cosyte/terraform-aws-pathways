---
id: quickstart
title: Quickstart
sidebar_label: Quickstart
description: "Deploy the smallest example, one engine, its database and one MLLP channel, into a VPC of your own, check it is healthy, then take it down."
---

# Quickstart

In this tutorial you deploy the [minimal example](./example-minimal.md): one Pathways engine on ECS
Fargate, its PostgreSQL database, and one channel that takes ADT messages over MLLP and sends each
admission on to a lab. At the end you take it all down again.

It runs in your own AWS account and bills while it exists: the
[example's page](./example-minimal.md#what-it-costs-to-leave-running) lists what. Every value in the
example is a placeholder, and every message you send it should be synthetic.

## Before you start

- Terraform 1.11 or later, the AWS CLI and Docker.
- Credentials for an AWS account where you may create ECS, RDS, KMS, Secrets Manager, Elastic Load
  Balancing and CloudWatch Logs resources.
- A VPC with two private subnets in two availability zones and a NAT gateway.

## 1. Copy the example

Copy `examples/minimal` out of this repository into a folder of your own, and point its module
source at the repository, with the commit or tag you want:

```hcl title="main.tf"
module "pathways" {
  source = "github.com/cosyte/terraform-aws-pathways?ref=<commit or tag>"
  # ...the rest as the example has it
}
```

## 2. Build your project's image

The example's `project/` folder is a Pathways project with one channel. Copy it into a project that
`pathways init` made, and add under `certs/`:

- the RDS global bundle, from `https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem`,
  as `rds-global-bundle.pem`: the database refuses connections without TLS;
- the MLLP source's certificate and key, as `server.pem` and `server.key`;
- the lab's certificate authority, as `lab-ca.pem`.

Build the image, push it to a registry, and note its digest. The Pathways docs cover this in
[Deploy the image](https://docs.cosyte.com/pathways/deploy-the-image).

## 3. Store the master key

The engine encrypts what it stores under a master key of 32 random bytes. Put one in Secrets
Manager:

```sh
aws secretsmanager create-secret --name pathways-minimal/master-key \
  --secret-string "$(openssl rand -base64 32)" --query ARN --output text
```

## 4. Set the variables

Write a `terraform.tfvars` beside the example's files with your own values:

```hcl title="terraform.tfvars"
region                = "us-east-1"
vpc_id                = "vpc-0a1b2c3d4e5f60718"
private_subnet_ids    = ["subnet-0a1b2c3d4e5f60718", "subnet-0f1e2d3c4b5a60718"]
allowed_cidr_blocks   = ["10.20.0.0/16"]
lab_cidr_blocks       = ["10.40.0.0/24"]
image                 = "123456789012.dkr.ecr.us-east-1.amazonaws.com/pathways-minimal@sha256:<digest>"
master_key_secret_arn = "<the ARN step 3 printed>"
```

## 5. Plan and apply

```sh
terraform init
terraform plan -out tfplan
terraform apply tfplan
```

The apply creates the key, the log groups, the security groups, the database and its secret, the
roles, the network load balancer, the cluster, the two task definitions and the service. The
database takes the longest, often several minutes.

## 6. Run the migrate task

The engine starts with `--no-migrate`, so it refuses a database without its schema, and ECS keeps
replacing it until the schema is there. Run the migrate task once:

```sh
cluster=$(terraform output -raw cluster_name)
task=$(aws ecs run-task --cluster "$cluster" --launch-type FARGATE \
  --task-definition "$(terraform output -raw migrate_task_definition_arn)" \
  --network-configuration "$(terraform output -raw migrate_network_configuration)" \
  --query 'tasks[0].taskArn' --output text)
aws ecs wait tasks-stopped --cluster "$cluster" --tasks "$task"
aws ecs describe-tasks --cluster "$cluster" --tasks "$task" \
  --query 'tasks[0].containers[0].exitCode' --output text
```

The last command prints `0` when the schema is in place.

## 7. Check the engine is healthy

```sh
aws ecs wait services-stable --cluster "$cluster" --services "$(terraform output -raw service_name)"
aws logs tail "$(terraform output -raw engine_log_group_name)" --since 10m
```

The service turns stable once the network load balancer finds the engine ready. The log lines are
the engine's own JSON, with ids, counts and codes, never a message's content.

Send a synthetic ADT A01 over MLLP with TLS from a machine in `allowed_cidr_blocks` to the address
`terraform output -raw nlb_dns_name` prints, on port 2575. The engine answers with an ACK and sends
the admission on to the lab.

## 8. Take it down

The example turns deletion protection off, so a destroy goes through:

```sh
terraform destroy
```

The destroy takes a final snapshot of the database, named `pathways-minimal-final`, and schedules
the module's key for deletion. The snapshot is billed until you delete it, and once the key is gone
it cannot be restored: see [Destroy a deployment](./destroy-a-deployment.md).

## Next

- [Turn on the bucket](./turn-on-the-bucket.md) and [give partners SFTP](./give-partners-sftp.md),
  as the [complete example](./example-complete.md) does.
- [Upgrade Pathways and the module](./upgrade.md): ship a new image, or a new version of the module.
- [Deployment shapes](./deployment-shapes.md): which pieces to add, and what they cost.
