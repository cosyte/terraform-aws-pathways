# complete

Pathways on ECS Fargate end to end, in an existing VPC:

- the engine and its PostgreSQL database;
- an S3 bucket the engine reaches through its task role, named to it as `PATHWAYS_BUCKET`;
- an SFTP server in front of the bucket, for one partner, the lab, whose home is `partners/lab`;
- the one channel in [`project/`](project) that joins them: ADT over MLLP in, admissions out to
  `partners/lab/outbox` in the bucket, which the lab sees as `/outbox` over SFTP.

Every value in [`variables.tf`](variables.tf) is a placeholder. To use it:

1. Copy `project/` into a project `pathways init` made, add the RDS global bundle and the MLLP
   source's certificate and key under `certs/`, build the project's image and push it.
2. Set the variables: your VPC and subnets, the image by digest, the master key's secret, the
   networks your MLLP senders and the lab connect from, and the lab's SSH public key.
3. Plan and apply from your own pipeline, with your own credentials. CI here only runs
   `terraform validate` on this directory; nothing in this repository applies it.

The README at the repository root lists what each part costs each month.
