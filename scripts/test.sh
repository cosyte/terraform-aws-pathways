#!/usr/bin/env bash
#
# Runs the module's tests: terraform test over each subject directory under tests/, against a mocked
# aws provider.
#
#   scripts/test.sh
#
# tests/ holds one directory per subject: tests/composition for the root module, and tests/<name>
# for each submodule under modules/<name>, whose run blocks name it with `module { source = ... }`.
# Every submodule must have its directory, so a new one cannot go untested.
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
  echo "scripts/test.sh: $*" >&2
  exit 1
}

[ -d tests/composition ] || fail "no tests/composition directory: the root module needs its tests"

shopt -s nullglob
for m in modules/*/; do
  m="$(basename "$m")"
  [ -d "tests/${m}" ] || fail "modules/${m} has no tests/${m} directory"
done

dirs=()
for d in tests/*/; do
  d="${d%/}"
  files=("${d}"/*.tftest.hcl)
  [ "${#files[@]}" -gt 0 ] || continue
  dirs+=("$d")
done
[ "${#dirs[@]}" -gt 0 ] || fail "no .tftest.hcl file under tests/"

for d in "${dirs[@]}"; do
  for f in "${d}"/*.tftest.hcl; do
    runs=$(grep -cE '^run "' "$f" || true)
    plans=$(grep -cE '^[[:space:]]+command[[:space:]]*=[[:space:]]*plan[[:space:]]*$' "$f" || true)
    commands=$(grep -cE '^[[:space:]]+command[[:space:]]*=' "$f" || true)
    [ "$runs" -gt 0 ] || fail "${f} has no run block"
    [ "$plans" -eq "$runs" ] && [ "$commands" -eq "$runs" ] \
      || fail "${f}: ${runs} run block(s) but ${plans} 'command = plan' line(s) of ${commands} command line(s); every run block must plan, never apply"
    grep -qE '^mock_provider "aws"' "$f" || fail "${f} does not mock the aws provider"
  done
done
shopt -u nullglob

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

failed=()
for d in "${dirs[@]}"; do
  echo "::group::${d}"
  if ! terraform init -backend=false -input=false -no-color -test-directory="$d" > /dev/null; then
    failed+=("${d} (init)")
  elif ! terraform test -no-color -test-directory="$d"; then
    failed+=("$d")
  fi
  echo "::endgroup::"
done

if [ "${#failed[@]}" -gt 0 ]; then
  printf 'scripts/test.sh: FAILED %s\n' "${failed[@]}" >&2
  exit 1
fi
echo "Tested ${#dirs[@]} subjects."
