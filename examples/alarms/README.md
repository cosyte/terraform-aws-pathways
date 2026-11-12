# alarms

The [minimal](../minimal) deployment with the module's alarms on, in an existing VPC:

- one engine on ECS Fargate, one vCPU and 2 GiB, and beside it in the same task a metrics
  collector (AWS Distro for OpenTelemetry) that reads the engine's `/metrics`;
- its PostgreSQL database on RDS, in one availability zone, with deletion protection off;
- a network load balancer with one MLLP listener;
- four CloudWatch alarms (store down, oldest pending age, refused messages, settled destinations
  failing) that publish to an SNS topic you already have;
- the one channel in [`project/`](project), whose `pathways.yaml` turns on the health endpoint on
  port 9090, at 127.0.0.1 inside the task.

The collector authenticates to the health endpoint with a token the module generates and keeps in
Secrets Manager; neither the plan nor the state holds it. It sends CloudWatch only the four metrics
the alarms read, with no channel or destination name.

Every value in [`variables.tf`](variables.tf) is a placeholder. To use it:

1. Copy `project/` into a project `pathways init` made, add the RDS global bundle, the MLLP source's
   certificate and key and the lab's CA under `certs/`, build the project's image and push it.
2. Create the SNS topic the alarms publish to, and subscribe to it.
3. Pick the collector's version on
   [public.ecr.aws/aws-observability/aws-otel-collector](https://gallery.ecr.aws/aws-observability/aws-otel-collector)
   and pin it by the digest the registry gives for it.
4. Set the variables: your VPC and subnets, both images by digest, the master key's secret, the
   topic, the networks your MLLP sender connects from and the lab's network.
5. Plan and apply from your own pipeline, with your own credentials. CI here only runs
   `terraform validate` and a mocked `terraform test` on this directory; nothing in this repository
   applies it.

The docs site's page for this example lists what each part bills for each month.

Not yet run against a live collector: the collector's configuration is checked by tests as data,
and has not been run against a real collector and engine. On a first apply, in a test account,
check that the four metrics reach CloudWatch under the `Pathways` namespace with only the
`Deployment` dimension (if another dimension appears, the alarms watch an empty metric and the store
down alarm fires continuously), and that the collector's task role has the permissions the exporter
needs (watch the collector's lines in the engine's log group, stream prefix `metrics-collector`, for
access denied). The collector is not restarted if it stops; start a new deployment of the service.
Turning the alarms off and on again within seven days fails on the secret's fixed name until you
restore it or delete it without its recovery window.
