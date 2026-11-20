#!/usr/bin/env bash
# Fail a migration a previous release cannot survive, and any committed push.
set -euo pipefail

usage() {
  cat <<'HELP'
usage: bin/check-migrations-expand-only.sh [<root>]
       bin/check-migrations-expand-only.sh --help

Scan every committed migration, <root>/services/*/src/db/migrations/*/migration.sql, for
statements that are not backward-compatible: dropping a table, column or
schema, renaming, changing a column type, making an existing column NOT NULL,
or truncating. There are no down migrations: the previous image has to keep
running against the database the next one migrated, so a migration may not
remove what the previous image still reads.

A migration that is deliberately the contract half of an expand-then-contract
pair says so in a comment, and is then allowed:

    -- contract: name was expanded in 20261015192638_initial and backfilled

Also fails when a committed package script or workflow runs the schema tool's
live-database push, which changes a database with no recorded migration.

<root> defaults to this repository. Comments and single-quoted strings are not
statements and are ignored. Needs no Bun, Node, Docker or credentials.
HELP
}

if [ "$#" -eq 1 ] && [ "$1" = --help ]; then usage; exit 0; fi
[ "$#" -le 1 ] || { usage >&2; exit 2; }
root="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)}"
[ -d "$root" ] || { echo "No such directory: $root" >&2; exit 2; }

# Err toward matching too much: a false positive is a visible argument, a false
# negative is a broken rollback.
destructive='DROP[[:space:]]+TABLE|DROP[[:space:]]+COLUMN|DROP[[:space:]]+SCHEMA|RENAME|ALTER[[:space:]]+COLUMN[^;]*[[:space:]]TYPE[[:space:]]|SET[[:space:]]+NOT[[:space:]]+NULL|TRUNCATE'
status=0
shopt -s nullglob

for sql in "$root"/services/*/src/db/migrations/*/migration.sql; do
  if grep -qiE '^[[:space:]]*--[[:space:]]*contract:' "$sql"; then
    echo "$sql: declared contract step, destructive statements allowed"
    continue
  fi
  # Stripping comments and strings line by line keeps grep's line numbers.
  while IFS= read -r statement; do
    [ -n "$statement" ] || continue
    echo "$sql:${statement%%:*}: not backward-compatible: ${statement#*:}" >&2
    status=1
  done < <(sed -e 's/--.*$//' -e "s/'[^']*'/''/g" "$sql" |
    grep -inE "$destructive" |
    sed -e 's/:[[:space:]]*/:/' -e 's/[[:space:]]*$//')
done

for committed in "$root"/services/*/package.json "$root"/.github/workflows/*.yml "$root"/.github/workflows/*.yaml; do
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    echo "$committed: committed live-database push: $line" >&2
    status=1
  done < <(grep -iE 'drizzle-kit[[:space:]]+push' "$committed" |
    sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
done

exit "$status"
