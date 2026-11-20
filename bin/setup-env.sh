#!/usr/bin/env bash
# Write this checkout's local .env from the committed .env.example. Safe to run again.
set -euo pipefail

if [ "${1:-}" = --help ] || [ "${1:-}" = -h ]; then
  cat <<'HELP'
Usage: bin/setup-env.sh

Writes .env from .env.example, readable only by you (mode 600). A variable
the example sets is copied as it is; one it leaves empty gets 32 random hex
characters, so every checkout has its own development values. A comment to
the right of a value is not part of it.

With a .env already there, every value in it is kept and only the variables
the example names and .env lacks are added: a password is never rotated under
a stack's data. Delete .env (and the stack's data, bin/down) to start over.

bin/setup and bin/up run this. Only .env.example is committed; .env is
ignored by git.
HELP
  exit 0
fi
[ "$#" -eq 0 ] || { echo "usage: bin/setup-env.sh" >&2; exit 2; }

# The checkout this script belongs to, whatever directory it runs from.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
EXAMPLE="$ROOT/.env.example"
ENV_FILE="$ROOT/.env"
[ -f "$EXAMPLE" ] || { echo "ERROR: $EXAMPLE not found." >&2; exit 1; }

random_value() { od -An -N16 -tx1 /dev/urandom | tr -d ' \n'; }

# Prints NAME<TAB>value for each variable line of the example, without the
# comment to the right of the value.
variables() {
  sed -n 's/^\([A-Z][A-Z0-9_]*\)=\(.*\)$/\1	\2/p' "$EXAMPLE" \
    | sed -e 's/[[:space:]]#.*$//' -e 's/[[:space:]]*$//'
}

has_variable() { grep -q "^$1=" "$ENV_FILE"; }

line_for() {
  if [ -n "$2" ]; then printf '%s=%s\n' "$1" "$2"; else printf '%s=%s\n' "$1" "$(random_value)"; fi
}

umask 077
if [ ! -f "$ENV_FILE" ]; then
  {
    echo "# Written by bin/setup from .env.example. Local only: never commit it."
    variables | while IFS=$'\t' read -r name value; do line_for "$name" "$value"; done
  } > "$ENV_FILE"
  chmod 600 "$ENV_FILE"
  echo "Wrote .env"
  exit 0
fi

added=""
while IFS=$'\t' read -r name value; do
  [ -n "$name" ] || continue
  has_variable "$name" && continue
  # A .env edited by hand may end without a newline.
  [ -z "$(tail -c 1 "$ENV_FILE")" ] || echo >> "$ENV_FILE"
  line_for "$name" "$value" >> "$ENV_FILE"
  added="$added $name"
done <<< "$(variables)"
chmod 600 "$ENV_FILE"
if [ -n "$added" ]; then
  echo "Added to .env:$added"
else
  echo ".env is up to date"
fi
