#!/usr/bin/env bash
#
# terraform init with no backend, then terraform validate, in the module's root and in each example.
# Neither reads a credential or calls AWS. Each directory's .terraform/ and lock file are removed on
# every exit path, so none is ever committed.
#
#   scripts/validate.sh

set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

export TF_IN_AUTOMATION=1
export TF_INPUT=0

shopt -s nullglob
dirs=(. examples/*/)
shopt -u nullglob
[ "${#dirs[@]}" -gt 1 ] || {
  echo "scripts/validate.sh: no example under examples/" >&2
  exit 1
}

cleanup() {
  for d in "${dirs[@]}"; do
    rm -rf "${d%/}/.terraform" "${d%/}/.terraform.lock.hcl"
  done
}
trap cleanup EXIT INT TERM

failed=()
for d in "${dirs[@]}"; do
  d="${d%/}"
  echo "::group::${d}"
  if ! terraform -chdir="$d" init -backend=false -input=false -no-color > /dev/null; then
    failed+=("${d} (init)")
  elif ! terraform -chdir="$d" validate -no-color; then
    failed+=("${d} (validate)")
  fi
  echo "::endgroup::"
done

if [ "${#failed[@]}" -gt 0 ]; then
  printf 'scripts/validate.sh: FAILED %s\n' "${failed[@]}" >&2
  exit 1
fi
echo "Validated ${#dirs[@]} directories."
