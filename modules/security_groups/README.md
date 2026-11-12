# security_groups

The security groups of a Pathways deployment, each opened only as far as the next hop needs:

```text
allowed_cidr_blocks -> network load balancer      the MLLP ports
allowed_cidr_blocks -> application load balancer  the HTTP ports
load balancers      -> engine                     their source ports and the probe port
engine              -> database                   5432
engine              -> egress_rules               HTTPS anywhere by default
```

A load balancer's group exists only when there is a source of its kind.

The root module calls it, and it can be used on its own:

```hcl
module "pathways_security_groups" {
  source = "github.com/cosyte/terraform-aws-pathways//modules/security_groups"

  name                = "integration"
  vpc_id              = "vpc-0a1b2c3d4e5f60718"
  allowed_cidr_blocks = ["10.20.0.0/16"]
  mllp_sources        = { adt = { port = 2575 } }
}
```

Inputs are in [`variables.tf`](variables.tf), outputs in [`outputs.tf`](outputs.tf).
