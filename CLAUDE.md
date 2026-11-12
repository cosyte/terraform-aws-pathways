# cosyte/terraform-aws-pathways

A Terraform module that provisions Cosyte Pathways on AWS ECS Fargate. It follows the public registry's
layout for a module with nested submodules:

- the root holds only `main.tf` (the composition, which calls the submodules), `variables.tf`,
  `outputs.tf` and `versions.tf`;
- `modules/<name>/` holds one concern each (`kms`, `logs`, `security_groups`, `database`, `iam`,
  `load_balancers`, `ecs`, and the optional `bucket` and `sftp`, off by default), with its own `main.tf`, `variables.tf`, `outputs.tf`, `versions.tf` and a
  short `README.md`, and each can be used on its own;
- `examples/` holds whole root modules that call it;
- `tests/<subject>/` holds the `terraform test` files: `tests/composition` for the root, and
  `tests/<name>` for each submodule;
- `scripts/` holds every command of the gate.

A new concern is a new submodule with its own `tests/<name>` directory, called from the root's
`main.tf`; `scripts/validate.sh` and `scripts/test.sh` refuse a layout that breaks these rules. Tools
pin in `mise.toml`.

## Gate

From the repo root, in this order, on the versions `mise.toml` pins. Each command names the tool it
needs, so mise installs only that one: mise's own install of tflint fails its attestation check, and
`scripts/policy.sh` downloads tflint at its pin instead, checked against the release's checksums.

```sh
mise exec terraform -- terraform fmt -check -recursive
scripts/check-no-emdash.sh
mise exec terraform -- scripts/validate.sh
mise exec trivy -- scripts/policy.sh
mise exec actionlint -- actionlint
mise exec terraform -- scripts/test.sh
```

- `scripts/validate.sh`: checks the layout above, then `terraform init -backend=false` and
  `terraform validate` in the root, in each `modules/` directory and in each `examples/` directory.
- `scripts/policy.sh`: tflint with the AWS ruleset (`.tflint.hcl`), then `trivy config` at HIGH and
  CRITICAL. An accepted trivy finding is an inline `#trivy:ignore:<ID>` with its reason, listed in the
  README.
- `scripts/test.sh`: `terraform test` over each `tests/<subject>/` directory, plan only, against a
  mocked aws provider, with every AWS credential taken away. It refuses a run block that does not
  plan, and a submodule without its test directory.

CI runs the same checks on every pull request, each its own job in `.github/workflows/ci.yml`
(`fmt`, `validate`, `tf-test`, `tf-policy`, `actionlint`), with `no-emdash` (the tracked files and
the pull request's title, body and commits) and `pr-title / conventional-commits` beside them. A
session never runs `terraform plan` or `apply` against an account: no credentials exist here.

## Hazard: this module creates infrastructure that carries PHI

A consumer applies this module in their own cloud account to run an engine that moves PHI-bearing
messages. A wrong default (a public endpoint, an unencrypted volume, a broad role, logs that carry
message bodies) exposes patient data in someone else's account, and they may not notice.

- Secure by default: private networking, encryption at rest and in transit, least privilege.
- No test or example applies to a real account. Tests plan against mocked providers only.
- No secret, account id or real hostname in any file. Synthetic values only.
- We, not third person. Cosyte with a capital C. No em or en dashes. The only compliance claim is that
  we sign Business Associate Agreements; never call software HIPAA compliant.
