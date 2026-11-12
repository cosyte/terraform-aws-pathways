# load_balancers

The load balancers of a Pathways deployment: a network load balancer with one TCP listener per MLLP
source, passed straight through to the engine, which terminates its own TLS, and an application
load balancer with one HTTPS listener per HTTP source (TLS 1.3 policy, invalid headers dropped).
Each exists only when there is a source of its kind, both are internal by default, and every target
group checks readiness, `GET /readyz` on the probe port.

The root module calls it, and it can be used on its own:

```hcl
module "pathways_load_balancers" {
  source = "github.com/cosyte/terraform-aws-pathways//modules/load_balancers"

  name                  = "integration"
  vpc_id                = "vpc-0a1b2c3d4e5f60718"
  subnet_ids            = ["subnet-0a1b2c3d4e5f60718", "subnet-0f1e2d3c4b5a60718"]
  mllp_sources          = { adt = { port = 2575 } }
  nlb_security_group_id = module.pathways_security_groups.nlb_security_group_id
}
```

The target group outputs wait for the listeners, so an ECS service that reads them attaches after
the listeners exist. Inputs are in [`variables.tf`](variables.tf), outputs in
[`outputs.tf`](outputs.tf).
