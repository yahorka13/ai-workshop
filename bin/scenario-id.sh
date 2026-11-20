#!/usr/bin/env bash
# Print fresh scenario IDs for a capability: <capability>-<6-hex>.
#
#     bin/scenario-id.sh app-shell 2
#     → app-shell-3f9c1a
#       app-shell-b07e2d
set -euo pipefail

usage() {
  cat <<'HELP'
usage: bin/scenario-id.sh <capability> [<count>]

Prints <count> (default 1) fresh scenario IDs for <capability>, one per line,
as <capability>-<hash>: 6 lowercase hex characters with at least one letter,
so the hash never reads like a numeric ID. No ID printed is carried by a
scenario of that capability in openspec/specs/ or an active change's delta
specs, and none is printed twice.

Every new scenario takes its ID from here, so branches open at the same time
never take the same one. Existing IDs never change.

The capability must have a spec folder in openspec/specs/ or in an active
change's specs/.
HELP
}

case "$#:${1:-}" in
  1:--help) usage; exit 0 ;;
  1:* | 2:*) CAPABILITY="$1"; COUNT="${2:-1}" ;;
  *) usage >&2; exit 2 ;;
esac
[[ "$COUNT" =~ ^[1-9][0-9]*$ ]] || { usage >&2; exit 2; }

ROOT="${OPENSPEC_ROOT:-$(git rev-parse --show-toplevel)}"
SOURCE="${SCENARIO_ID_SOURCE:-/dev/urandom}"

# The capability's spec files: the main spec and every active change's delta.
SPECS=()
[ -f "$ROOT/openspec/specs/$CAPABILITY/spec.md" ] && SPECS+=("$ROOT/openspec/specs/$CAPABILITY/spec.md")
for file in "$ROOT"/openspec/changes/*/specs/"$CAPABILITY"/spec.md; do
  case "$file" in "$ROOT/openspec/changes/archive/"*) continue ;; esac
  [ -f "$file" ] && SPECS+=("$file")
done
if [ "${#SPECS[@]}" -eq 0 ]; then
  echo "scenario-id: no spec folder for capability '$CAPABILITY'" >&2
  usage >&2
  exit 2
fi

# Hashes already taken, by the specs and by this run.
TAKEN=" $(grep -hoE "^#### Scenario: \[$CAPABILITY-[0-9a-z]+\]" "${SPECS[@]}" \
  | sed -E "s/^#### Scenario: \[$CAPABILITY-//; s/\]$//" | tr '\n' ' ' || true) "

# Three bytes per candidate: twice the count plus 200 spare, since about one
# in sixteen is all digits and a few may be taken.
CANDIDATES="$(head -c $((3 * (2 * COUNT + 200))) "$SOURCE" | od -An -v -tx1 | tr -d ' \n')"
printed=0
while [ "$printed" -lt "$COUNT" ] && [ "${#CANDIDATES}" -ge 6 ]; do
  hash="${CANDIDATES:0:6}"
  CANDIDATES="${CANDIDATES:6}"
  [[ "$hash" =~ [a-f] ]] || continue
  [[ "$TAKEN" == *" $hash "* ]] && continue
  TAKEN="$TAKEN$hash "
  echo "$CAPABILITY-$hash"
  printed=$((printed + 1))
done

if [ "$printed" -lt "$COUNT" ]; then
  echo "scenario-id: could not find a free hash; run it again" >&2
  exit 1
fi
