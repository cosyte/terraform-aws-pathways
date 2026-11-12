#!/usr/bin/env bash
#
# Policy checks over the module, its submodules and its examples: tflint with the AWS ruleset, then
# trivy's misconfiguration scan. Neither needs AWS credentials: both read the .tf files only.
#
#   scripts/policy.sh
#
# VERSIONS. tflint and trivy are pinned in mise.toml and this script reads the pins from there, so
# CI and a laptop cannot drift. If the binary on PATH is the pinned version it is used; otherwise the
# pinned release is downloaded from GitHub into a cache directory and checked against the checksums
# file the same release publishes (which catches a corrupt download, not a compromised release).
#
# WHAT EACH CHECK READS.
#   * tflint: .tflint.hcl at the repository root (the rulesets, pinned there), over every directory
#     holding a .tf file.
#   * trivy config: HIGH and CRITICAL only, with the checks bundle embedded in the pinned binary (no
#     download of newer checks, so a run is reproducible). An accepted finding is an inline
#     `#trivy:ignore:<ID>` directive with its reason beside it; the README lists each one.

set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

fail() {
  echo "scripts/policy.sh: $*" >&2
  exit 1
}

pin() {
  local v
  v=$(awk -F'"' -v k="$1" '$0 ~ "^" k "[[:space:]]*=" {print $(NF-1)}' mise.toml)
  [ -n "$v" ] || fail "no ${1} pin in mise.toml"
  printf '%s' "$v"
}

cache="${XDG_CACHE_HOME:-$HOME/.cache}/cosyte-terraform-policy"

# fetch <name> <version> <asset> <checksums asset> <url base> <extract command...>
fetch() {
  local name="$1" version="$2" asset="$3" sums="$4" base="$5"
  shift 5
  local dir="${cache}/${name}-${version}"
  if [ ! -x "${dir}/${name}" ]; then
    echo "Fetching ${name} ${version}" >&2
    rm -rf "$dir"
    mkdir -p "$dir"
    curl -fsSL --retry 3 -o "${dir}/${asset}" "${base}/${asset}"
    curl -fsSL --retry 3 -o "${dir}/checksums.txt" "${base}/${sums}"
    # Everything here reports on stderr: stdout carries only the binary's path.
    (cd "$dir" && grep -E "[[:space:]]\*?${asset}\$" checksums.txt | sha256sum -c - >&2)
    (cd "$dir" && "$@" "$asset" >&2)
    [ -x "${dir}/${name}" ] || fail "${name} ${version}: the download held no ${name} binary"
  fi
  printf '%s' "${dir}/${name}"
}

tflint_version="$(pin tflint)"
trivy_version="$(pin trivy)"

if command -v tflint > /dev/null 2>&1 && tflint --version 2> /dev/null | head -1 | grep -qF "version ${tflint_version}"; then
  TFLINT="$(command -v tflint)"
else
  TFLINT="$(fetch tflint "$tflint_version" tflint_linux_amd64.zip checksums.txt \
    "https://github.com/terraform-linters/tflint/releases/download/v${tflint_version}" unzip -q -o)"
fi

if command -v trivy > /dev/null 2>&1 && trivy --version 2> /dev/null | head -1 | grep -qF "Version: ${trivy_version}"; then
  TRIVY="$(command -v trivy)"
else
  TRIVY="$(fetch trivy "$trivy_version" "trivy_${trivy_version}_Linux-64bit.tar.gz" "trivy_${trivy_version}_checksums.txt" \
    "https://github.com/aquasecurity/trivy/releases/download/v${trivy_version}" tar -xzf)"
fi

"$TFLINT" --version
"$TRIVY" --version | head -1

rc=0

echo "::group::tflint (AWS ruleset), every Terraform directory"
"$TFLINT" --init --config="${root}/.tflint.hcl"
if ! "$TFLINT" --recursive --config="${root}/.tflint.hcl" --format=compact; then
  rc=1
fi
echo "::endgroup::"

echo "::group::trivy config, HIGH and CRITICAL"
if ! "$TRIVY" config --quiet --exit-code 1 --severity HIGH,CRITICAL \
  --skip-check-update --skip-dirs '**/.terraform' "$root"; then
  rc=1
fi
echo "::endgroup::"

if [ "$rc" -ne 0 ]; then
  fail "policy findings above: fix each, or accept it with an inline #trivy:ignore and its reason, listed in the README"
fi
echo "Policy checks clean."
