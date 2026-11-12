#!/usr/bin/env bash
#
# Writes the generated parts of docs-content/ from the code (scripts/docs_content.py), then fails if
# that changed anything git knows, or left a new file git does not, so a page that no longer matches
# the code fails CI. It also fails when a folder under examples/ has no page, or a page is missing
# from the sidebar. Run it, and commit what it wrote.
#
#   scripts/docs.sh
#
# Needs terraform-docs, at the version mise.toml pins, and python3.

set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

fail() {
  echo "scripts/docs.sh: $*" >&2
  exit 1
}

command -v terraform-docs > /dev/null || fail "terraform-docs is not on PATH: run it as mise exec terraform-docs -- scripts/docs.sh"
command -v python3 > /dev/null || fail "python3 is not on PATH"

want="$(awk -F'"' '/^terraform-docs[[:space:]]*=/ {print $(NF-1)}' mise.toml)"
have="$(terraform-docs --version | awk '{print $3}')"
[ "v${want}" = "${have}" ] || [ "${want}" = "${have}" ] \
  || fail "terraform-docs is ${have}, and mise.toml pins ${want}: another version writes other pages"

python3 scripts/docs_content.py || fail "docs-content/ is incomplete: see the lines above"

untracked="$(git ls-files --others --exclude-standard -- docs-content)"
if ! git diff --quiet -- docs-content || [ -n "$untracked" ]; then
  git --no-pager diff --stat -- docs-content
  [ -z "$untracked" ] || printf 'new: %s\n' $untracked
  fail "the generated pages did not match the code: this run rewrote them, so review and commit them"
fi
echo "scripts/docs.sh: docs-content/ matches the code."
