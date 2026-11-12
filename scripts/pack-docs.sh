#!/usr/bin/env bash
#
# Builds the two archives a release carries for docs.cosyte.com, into an output directory (the first
# argument, dist-artifacts by default):
#
#   docs-content.tar.gz   the tracked files of docs-content/, at the archive root, as the working
#                         tree holds them (the release fills in the "Current numbers" sections
#                         before this runs)
#   source.tar.gz         the module's source as git tracks it: the root's .tf files, modules/,
#                         examples/, README.md, CHANGELOG.md and LICENSE
#
#   scripts/pack-docs.sh [output directory]
#
# Both are reproducible: members in name order, owned by 0:0, dated by the commit, gzip without a
# name or a time. Both are built before the output directory is touched, so a run that fails leaves
# no half-built pair behind.

set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"
out="${1:-dist-artifacts}"

fail() {
  echo "scripts/pack-docs.sh: $*" >&2
  exit 1
}

for f in docs-content/intro.md docs-content/sidebars.json; do
  [ -f "$f" ] || fail "${f} is missing: the docs site needs it in every docs-content.tar.gz"
done

epoch="$(git log -1 --format=%ct)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

pack() {
  local dir="$1" list="$2" archive="$3"
  [ -s "$list" ] || fail "nothing to put in ${archive}"
  tar --create --format=ustar --sort=name --mtime="@${epoch}" --owner=0 --group=0 --numeric-owner \
    --mode='u+rw,go+r,go-w' --directory="$dir" --null --files-from="$list" \
    | gzip -n -9 > "${work}/${archive}"
}

# docs-content/: its tracked files, named from inside it.
(cd docs-content && git ls-files -z) > "${work}/docs.list"
pack docs-content "${work}/docs.list" docs-content.tar.gz

# The module's source.
git ls-files -z -- '*.tf' modules examples README.md CHANGELOG.md LICENSE \
  | while IFS= read -r -d '' f; do
    case "$f" in
      tests/* | scripts/* | .github/*) ;;
      *) printf '%s\0' "$f" ;;
    esac
  done > "${work}/source.list"
pack . "${work}/source.list" source.tar.gz

mkdir -p "$out"
mv "${work}/docs-content.tar.gz" "${work}/source.tar.gz" "$out/"
for a in docs-content.tar.gz source.tar.gz; do
  echo "${out}/${a}: $(tar -tzf "${out}/${a}" | wc -l) files"
done
