# cosyte/terraform-aws-pathways

A Terraform module that provisions Cosyte Pathways on AWS ECS Fargate. It follows the public registry's
layout for one module per repository: `versions.tf`, `variables.tf`, `main.tf`, `outputs.tf`, an
`examples/` directory and a `tests/` directory. Tools pin in `mise.toml`.

## Gate

From the repo root, in this order, on the versions `mise.toml` pins. Each command names the tool it
needs, so mise installs only that one: mise's own install of tflint fails its attestation check, and
`tests/policy/run.sh` downloads tflint at its pin instead, checked against the release's checksums.

```sh
mise exec terraform -- terraform fmt -check -recursive
scripts/check-no-emdash.sh
mise exec terraform -- scripts/validate.sh
mise exec trivy -- tests/policy/run.sh
mise exec actionlint -- actionlint
mise exec terraform -- tests/run.sh
```

- `scripts/validate.sh`: `terraform init -backend=false` and `terraform validate`, in the root and in
  each `examples/` directory.
- `tests/policy/run.sh`: tflint with the AWS ruleset (`.tflint.hcl`), then `trivy config` at HIGH and
  CRITICAL. An accepted trivy finding is an inline `#trivy:ignore:<ID>` with its reason, listed in the
  README.
- `tests/run.sh`: `terraform test` over `tests/*.tftest.hcl`, plan only, against a mocked aws provider,
  with every AWS credential taken away. It refuses a run block that does not plan.

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
