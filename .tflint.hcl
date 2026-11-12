# tflint configuration for the module and its examples, read by tests/policy/run.sh (locally, in
# the gate in CLAUDE.md, and in the tf-policy job of .github/workflows/ci.yml). tflint itself is
# pinned in mise.toml; the rulesets are pinned here by exact version, and tflint verifies the AWS
# ruleset's signature when it installs it.

config {
  # Evaluate the examples' calls into the module, so their arguments are linted against it.
  call_module_type = "local"
}

plugin "terraform" {
  enabled = true
  preset  = "all"
}

plugin "aws" {
  enabled = true
  version = "0.50.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}
