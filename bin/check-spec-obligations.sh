#!/usr/bin/env bash
# Fail on a requirement that bundles several obligations (principle: one
# obligation per requirement).
#
#     bin/check-spec-obligations.sh [--base <ref>]
set -euo pipefail
export LC_ALL=C # the keyword scan reads ASCII

usage() {
  cat <<'HELP'
usage: bin/check-spec-obligations.sh [--base <ref>]

A requirement's obligations are the SHALL and MUST keywords in its text, not
in its scenarios, code spans or double quotes; SHALL NOT and MUST NOT count
once. A requirement with more than one is bundled. The check fails, listing
every problem, when:

  - an active change's delta (openspec/changes/<change>/specs/) ADDs or
    MODIFIES a bundled requirement;
  - with --base <ref>, a bundled requirement in openspec/specs/ was added
    since <ref>, or its text changed (CI passes the pull request's base); a
    change to its scenarios alone does not count.

A requirement moved unchanged (the same name and text in another capability)
is not new. Split a bundled requirement into one requirement per SHALL or
MUST; a sentence that only qualifies another folds into it as a clause.

Bundled requirements already in openspec/specs/ pass until something changes
them; the check prints how many there are, so the number can be watched
falling.

Exits 0 on success, 1 on a finding, 2 on bad arguments.
HELP
}

BASE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --help) usage; exit 0 ;;
    --base) [ $# -ge 2 ] || { usage >&2; exit 2; }; BASE="$2"; shift ;;
    *) usage >&2; exit 2 ;;
  esac
  shift
done

# shellcheck source=bin/spec
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/spec"

TOP="$(root)"
cd "$TOP"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# shellcheck disable=SC2016 # a jq program
# A quoted or code span ends within its sentence, so a stray quote hides nothing.
COUNT='def obligations: gsub("`(?:(?!\\. )[^`\n])*`"; "") | gsub("\"(?:(?!\\. )[^\"\n])*\""; "") | [scan("\\b(SHALL|MUST)( NOT)?\\b")] | length;'

load_specs "$TOP" > "$WORK/specs.json" || exit 2

: > "$WORK/errors"
error() { printf '%s\n' "$*" >> "$WORK/errors"; }
split_hint='split it into one requirement per SHALL or MUST'

# 1. Active changes: ADDED and MODIFIED requirements, unless moved unchanged.
jq "$FLATTEN"' | map({name, text})' "$WORK/specs.json" > "$WORK/main.json"
for dir in openspec/changes/*/; do
  change="$(basename "$dir")"
  [ "$change" != archive ] && [ -d "$dir/specs" ] || continue
  "$OPENSPEC" show "$change" --json --deltas-only 2> /dev/null > "$WORK/delta.json" || true
  jq -r --slurpfile main "$WORK/main.json" "$COUNT"'
    select(.deltas) | .deltas[] | select(.operation == "ADDED" or .operation == "MODIFIED")
    | .spec as $cap | .requirement
    | select((.text | obligations) > 1)
    | select(. as $r | $main[0] | any(.name == $r.name and .text == $r.text) | not)
    | "\($cap)\t\(.name)\t\(.text | obligations)"
  ' "$WORK/delta.json" | while IFS=$'\t' read -r cap name n; do
    file="openspec/changes/$change/specs/$cap/spec.md"
    line="$(grep -n -F -x "### Requirement: $name" "$file" | head -1 | cut -d: -f1)"
    error "$file:${line:-?}: $name has $n obligations; $split_hint"
  done
done

# 2. Since the base: requirements in openspec/specs/ whose text is new or
# changed; an edit to a scenario alone leaves the requirement as it was.
if [ -n "$BASE" ]; then
  base="$(base_ref "$BASE")"
  changes_json "$TOP" "$base" > "$WORK/changes.json" || exit 2
  jq -r "$COUNT"' (.added + [.modified[] | select(.text_changed)])[] | select((.text | obligations) > 1)
    | "\(.file):\(.line): \(.name) has \(.text | obligations) obligations; '"$split_hint"'"' \
    "$WORK/changes.json" >> "$WORK/errors"
fi

if [ -s "$WORK/errors" ]; then
  cat "$WORK/errors" >&2
  exit 1
fi
echo "spec-obligations: no new bundled requirement; $(jq "$COUNT"' [.[].requirements[] | select((.text | obligations) > 1)] | length' "$WORK/specs.json") remain in openspec/specs/"
