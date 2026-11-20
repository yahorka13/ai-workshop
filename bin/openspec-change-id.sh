#!/usr/bin/env bash
# Print a new OpenSpec change name: <issue>-<6-hex>-<slug>.
#
#     bin/openspec-change-id.sh 1096 "Referral credits per side"
#     → 1096-a3f9c1-referral-credits-per-side
#
# The hash is what commit subjects carry (`[1096][a3f9c1] ...`), so it must be
# unique across active changes, archived changes and branches, and must never
# be all digits - an all-digit hash in brackets reads like an issue number.
set -euo pipefail

usage() {
  echo "usage: $0 <issue-number> <slug or title>" >&2
  exit 2
}

[ $# -eq 2 ] || usage
ISSUE="$1"
[[ "$ISSUE" =~ ^[0-9]+$ ]] || usage

SLUG=$(printf '%s' "$2" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//' | cut -c1-40 | sed -E 's/-+$//')
[ -n "$SLUG" ] || usage

ROOT="${OPENSPEC_ROOT:-$(git rev-parse --show-toplevel)}"
CHANGES="$ROOT/openspec/changes"

hash_taken() {
  local hash="$1"
  compgen -G "$CHANGES/*-$hash-*" >/dev/null && return 0
  compgen -G "$CHANGES/archive/*-$hash-*" >/dev/null && return 0
  git -C "$ROOT" branch -a --format='%(refname:short)' 2>/dev/null | grep -q -- "-$hash-" && return 0
  return 1
}

for _ in $(seq 1 50); do
  HASH=$(od -An -N3 -tx1 /dev/urandom | tr -d ' \n')
  [[ "$HASH" =~ ^[0-9]+$ ]] && continue
  hash_taken "$HASH" && continue
  echo "$ISSUE-$HASH-$SLUG"
  exit 0
done

echo "$0: could not find a free hash after 50 attempts" >&2
exit 1
