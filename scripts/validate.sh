#!/usr/bin/env bash
#
# Checks the repository's layout, then runs terraform init with no backend and terraform validate in
# the root module, in each submodule under modules/ and in each example. Neither reads a credential
# or calls AWS. Each directory's .terraform/ and lock file are removed on every exit path, so none is
# ever committed.
#
#   scripts/validate.sh
#
# The layout is the registry's standard one for a module with nested submodules:
#   * the root holds only main.tf (the composition), variables.tf, outputs.tf and versions.tf;
#   * each modules/<name>/ holds main.tf, variables.tf, outputs.tf, versions.tf and a README.md.

set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"
export TF_IN_AUTOMATION=1
export TF_INPUT=0

fail() {
  echo "scripts/validate.sh: $*" >&2
  exit 1
}

# ---------------------------------------------------------------------------
# Layout
# ---------------------------------------------------------------------------

shopt -s nullglob
root_files=(*.tf)
modules=(modules/*/)
examples=(examples/*/)
shopt -u nullglob

[ "$(printf '%s\n' "${root_files[@]}" | sort | tr '\n' ' ')" = "main.tf outputs.tf variables.tf versions.tf " ] \
  || fail "the root must hold only main.tf, variables.tf, outputs.tf and versions.tf; it holds: ${root_files[*]}"

[ "${#modules[@]}" -gt 0 ] || fail "no submodule under modules/"
for m in "${modules[@]}"; do
  m="${m%/}"
  for f in main.tf variables.tf outputs.tf versions.tf README.md; do
    [ -f "${m}/${f}" ] || fail "${m} has no ${f}"
  done
done

[ "${#examples[@]}" -gt 0 ] || fail "no example under examples/"

echo "Layout: the root, ${#modules[@]} submodules and ${#examples[@]} examples."

# ---------------------------------------------------------------------------
# init and validate
# ---------------------------------------------------------------------------

dirs=(. "${modules[@]}" "${examples[@]}")

# Every directory needs the same providers: download them once, into a cache that lives as long as
# this run. The lock files are removed at the end anyway, so the cache may write them with this
# platform's checksums alone.
plugin_cache=""
if [ -z "${TF_PLUGIN_CACHE_DIR:-}" ]; then
  plugin_cache="$(mktemp -d)"
  export TF_PLUGIN_CACHE_DIR="$plugin_cache"
fi
export TF_PLUGIN_CACHE_MAY_BREAK_DEPENDENCY_LOCK_FILE=true

cleanup() {
  for d in "${dirs[@]}"; do
    rm -rf "${d%/}/.terraform" "${d%/}/.terraform.lock.hcl"
  done
  if [ -n "$plugin_cache" ]; then
    rm -rf "$plugin_cache"
  fi
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
