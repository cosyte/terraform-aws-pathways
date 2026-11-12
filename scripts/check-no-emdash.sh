#!/usr/bin/env bash
# scripts/check-no-emdash.sh
#
# Brand rule: Cosyte never uses the em dash (U+2014) or the en dash (U+2013), in any file, commit
# message, pull request title or pull request body. Write a range with "to", and a pause with a
# period, a colon, a comma or parentheses.
#
#   scripts/check-no-emdash.sh                 scan every tracked file
#   scripts/check-no-emdash.sh --stdin LABEL   scan text on stdin (CI feeds it the pull request's
#                                              title and body and the branch's commit messages)
#
# It fails closed: an empty input, an unreadable or non-regular tracked file, or any error from grep
# is a failure, never an OK from a scan that did not read everything.

set -euo pipefail

# grep -P reads a code point escape only in a UTF-8 locale.
export LC_ALL=C.UTF-8

# Each dash as the character itself and in five encodings: the URL form, the JavaScript escape, the
# named HTML entity, and the decimal and hex character references. The pattern is assembled from
# pieces so that this file never holds one whole, and the whole repository, this file included, is
# scanned with the same pattern.
pattern_for() {
  local cp="$1" url="$2" name="$3" dec="$4"
  printf '%s' "\\x{${cp}}|%E2%80%${url}|\\\\u${cp}|&${name};|&#${dec};|&#x${cp};"
}
PATTERN="$(pattern_for 2014 94 mdash 8212)|$(pattern_for 2013 93 ndash 8211)"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

fail() {
  echo "check-no-emdash: $*" >&2
  exit 1
}

# scan <label> <file...>: prints the hits and fails on any; fails on any grep error.
scan() {
  local label="$1"
  shift
  local rc=0
  grep -H -nP -e "$PATTERN" -- "$@" > "$work/hits" 2> "$work/errors" || rc=$?
  if [ -s "$work/errors" ] || [ "$rc" -gt 1 ]; then
    cat "$work/errors" >&2
    fail "grep could not read all of ${label}, so the scan is incomplete"
  fi
  if [ "$rc" -eq 0 ]; then
    cat "$work/hits" >&2
    fail "em or en dash in ${label}: rewrite each line above without it"
  fi
}

if [ "${1:-}" = "--stdin" ]; then
  label="${2:-stdin}"
  cat > "$work/stdin"
  [ -s "$work/stdin" ] || fail "nothing arrived on stdin for ${label}"
  scan "$label" "$work/stdin"
  echo "check-no-emdash: OK (${label})"
  exit 0
fi

cd "$(git rev-parse --show-toplevel)"
git ls-files -z > "$work/list"
[ -s "$work/list" ] || fail "no tracked files to scan"

files=()
while IFS= read -r -d '' f; do
  { [ -f "$f" ] && [ ! -L "$f" ]; } || fail "tracked entry is not a regular file: $f"
  [ -r "$f" ] || fail "tracked file is not readable: $f"
  files+=("./$f")
done < "$work/list"

scan "the tracked files" "${files[@]}"
echo "check-no-emdash: OK (${#files[@]} tracked files)"
