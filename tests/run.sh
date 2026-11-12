#!/usr/bin/env bash
#
# Runs the module's tests: terraform test over tests/*.tftest.hcl, against a mocked aws provider.
#
#   tests/run.sh
#
# A test that reached a real account would be worse than none, so before terraform runs this
# script checks that:
#   * every run block says `command = plan` (terraform test defaults to apply);
#   * every test file mocks the aws provider;
# and it takes every AWS credential away from terraform: the credential variables are unset, the
# config and credentials files point at /dev/null, and the instance metadata lookup is off. A test
# that tried to reach AWS fails to configure a provider instead of finding credentials.
#
# The random provider is real: it runs locally and calls nothing. The .terraform/ and lock file
# that `terraform init` writes are removed on every exit path.

set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

fail() {
  echo "tests/run.sh: $*" >&2
  exit 1
}

shopt -s nullglob
files=(tests/*.tftest.hcl)
shopt -u nullglob
[ "${#files[@]}" -gt 0 ] || fail "no .tftest.hcl file under tests/"

for f in "${files[@]}"; do
  runs=$(grep -cE '^run "' "$f" || true)
  plans=$(grep -cE '^[[:space:]]+command[[:space:]]*=[[:space:]]*plan[[:space:]]*$' "$f" || true)
  commands=$(grep -cE '^[[:space:]]+command[[:space:]]*=' "$f" || true)
  [ "$runs" -gt 0 ] || fail "${f} has no run block"
  [ "$plans" -eq "$runs" ] && [ "$commands" -eq "$runs" ] \
    || fail "${f}: ${runs} run block(s) but ${plans} 'command = plan' line(s) of ${commands} command line(s); every run block must plan, never apply"
  grep -qE '^mock_provider "aws"' "$f" || fail "${f} does not mock the aws provider"
done

unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN AWS_SECURITY_TOKEN \
  AWS_PROFILE AWS_DEFAULT_PROFILE AWS_ROLE_ARN AWS_ROLE_SESSION_NAME \
  AWS_WEB_IDENTITY_TOKEN_FILE AWS_CONTAINER_CREDENTIALS_FULL_URI \
  AWS_CONTAINER_CREDENTIALS_RELATIVE_URI AWS_CONTAINER_AUTHORIZATION_TOKEN
export AWS_CONFIG_FILE=/dev/null
export AWS_SHARED_CREDENTIALS_FILE=/dev/null
export AWS_EC2_METADATA_DISABLED=true
export TF_IN_AUTOMATION=1
export TF_INPUT=0

cleanup() {
  rm -rf "${root}/.terraform" "${root}/.terraform.lock.hcl"
}
trap cleanup EXIT INT TERM

terraform init -backend=false -input=false -no-color > /dev/null
terraform test -no-color
