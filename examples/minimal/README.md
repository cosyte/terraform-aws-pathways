# minimal

The smallest deployment of the module, in an existing VPC:

- one engine on ECS Fargate, half a vCPU and 1 GiB;
- its PostgreSQL database on RDS, in one availability zone, with deletion protection off;
- a network load balancer with one MLLP listener;
- the one channel in [`project/`](project): ADT over MLLP in, admissions over MLLP out to the lab.

No HTTP source, no bucket and no SFTP. It is sized for trying the module out: before it carries real
traffic, put `database_multi_az` and `deletion_protection` back to their defaults (both `true`).

Every value in [`variables.tf`](variables.tf) is a placeholder. To use it:

1. Copy `project/` into a project `pathways init` made, add the RDS global bundle, the MLLP source's
   certificate and key and the lab's CA under `certs/`, build the project's image and push it.
2. Set the variables: your VPC and subnets, the image by digest, the master key's secret, the
   networks your MLLP sender connects from and the lab's network.
3. Plan and apply from your own pipeline, with your own credentials. CI here only runs
   `terraform validate` on this directory; nothing in this repository applies it.

The docs site's page for this example, and the README at the repository root, list what each part
costs each month.
