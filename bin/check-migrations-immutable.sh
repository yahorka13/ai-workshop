#!/usr/bin/env bash
# Fail a change that edits a migration the base branch already applied.
set -euo pipefail

usage() {
  cat <<'HELP'
usage: bin/check-migrations-immutable.sh <base> <head>
       bin/check-migrations-immutable.sh --help

Compare the migrations under services/*/src/db/migrations between two refs and
fail when one that <base> already contains is modified, deleted or renamed.
An applied migration is history: two databases that recorded the same migration
must mean the same thing by it, so new behaviour is a new migration.

Adding a migration folder, <timestamp>_<name>/ with its migration.sql and
snapshot.json, passes. Only the newest migration keeps a snapshot, so deleting
an applied migration's snapshot.json passes when <head> keeps one in a newer
folder, including when git reports the pair as a rename. Any other change to
an applied migration or its snapshot fails.

Needs git only: no Bun, Node, Docker or credentials.
HELP
}

if [ "$#" -eq 1 ] && [ "$1" = --help ]; then usage; exit 0; fi
[ "$#" -eq 2 ] || { usage >&2; exit 2; }
base="$1"
head="$2"
for ref in "$base" "$head"; do
  git rev-parse --verify --quiet "$ref" > /dev/null ||
    { echo "Unknown ref: $ref" >&2; exit 2; }
done

# Whether <head> keeps a snapshot in a migration folder sorting after $1.
newer_snapshot() {
  local kept
  while IFS= read -r kept; do
    [[ "${kept%/snapshot.json}" > "$1" ]] && return 0
  done < <(git ls-tree -r --name-only "$head" -- "${1%/*}/" | grep '/snapshot\.json$')
  return 1
}

status=0
while IFS=$'\t' read -r code path renamed; do
  [ -n "${code:-}" ] || continue
  # Only the newest migration keeps a snapshot: an older one goes once a
  # newer folder holds one.
  if [[ "$path" == */snapshot.json ]]; then
    migration="${path%/snapshot.json}"
    if [[ "$code" == R* && "${renamed:-}" == */snapshot.json && "${renamed%/snapshot.json}" > "$migration" ]]; then continue; fi
    if [[ "$code" == D ]] && newer_snapshot "$migration"; then continue; fi
  fi
  case "$code" in
    A) continue ;;
    D) echo "$path: already applied, never delete a migration" >&2 ;;
    R*) echo "$path: already applied, never rename a migration (to ${renamed:-?})" >&2 ;;
    *) echo "$path: already applied, never edit a migration" >&2 ;;
  esac
  status=1
done < <(git diff --name-status --find-renames "$base...$head" -- 'services/*/src/db/migrations/*')

exit "$status"
