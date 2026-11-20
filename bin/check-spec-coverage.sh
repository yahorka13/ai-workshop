#!/usr/bin/env bash
# Fail when a spec scenario is not traced to an end-to-end test (principle 14).
#
#     bin/check-spec-coverage.sh [<root>]
set -euo pipefail
LC_ALL=C

MARK='- **NO E2E**'
CATEGORIES="internal-rule, not-built, external"

usage() {
  cat <<'HELP'
usage: bin/check-spec-coverage.sh [<root>]

Checks the OpenSpec specs under <root> (default: this repository) and fails,
listing every problem, when:

  - a scenario in openspec/specs/<capability>/spec.md or in an active change's
    delta spec does not start its name with [<capability>-<hash>]: the hash
    is 6 lowercase hex characters with at least one letter, from
    bin/scenario-id.sh <capability>, so branches open at the same time never
    take the same ID; a numeric ID such as [auth-3] is never valid;
  - two scenarios in the main specs share an ID;
  - a scenario in openspec/specs/ is neither cited by an end-to-end test nor
    excluded.

IDs never change. A scenario moved to another capability keeps its ID, so its
prefix names the capability it was written in: a main spec accepts the prefix
of a capability that has a folder in openspec/specs/; a change's delta accepts
another capability's prefix only for an ID the main specs carry.

A citation is the full ID in brackets, one ID per bracket, anywhere in a file
under services/e2e/tests/ or bin/tests/ (the black-box suites); citations in
service unit or integration tests do not count. "[x-a1b2c3, d4e5f6]" cites
only x-a1b2c3.

A scenario no end-to-end test can reach is excluded by a line of its own, in
the main spec, after its WHEN and THEN lines:

    - **NO E2E** <category>: <reason>

where the category says why the scenario has no end-to-end test:

  internal-rule  a rule enforced inside one service (database constraint,
                 typecheck, lint) or a repository Claude Code plugin; the
                 reason names the test file that covers it, which must exist
  not-built      no screen or API exposes it yet; it gets a test when it ships
  external       needs real cloud, operator credentials or a deployed
                 environment, which CI cannot reach

An exclusion fails when it has no category or reason, is not inside a
scenario, repeats in one scenario, or excludes a scenario a test now cites:
remove it then.
HELP
}

case "${1:-}" in
  --help) [ "$#" -eq 1 ] || { usage >&2; exit 2; }; usage; exit 0 ;;
  -*) usage >&2; exit 2 ;;
esac
case "$#" in
  0) ROOT="$(git rev-parse --show-toplevel)" ;;
  1) ROOT="$1" ;;
  *) usage >&2; exit 2 ;;
esac
[ -d "$ROOT" ] || { echo "spec-coverage: no such directory: $ROOT" >&2; exit 2; }
ROOT="$(cd "$ROOT" && pwd -P)"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
: > "$WORK/errors"
error() { printf '%s\n' "$*" >> "$WORK/errors"; }

# check_headings <file> <capability> <main|change>: report malformed scenario
# names, and write each main-spec exclusion as "<id>\t<file>:<line>\t<line>"
# to $WORK/marks. For each well-formed one in the main specs, print
# "<id> <file>". An ID whose prefix names another capability is a moved
# scenario: in the main specs the prefix must be a live capability
# ($WORK/known); in a change it is written to $WORK/borrowed, and must be an
# ID the main specs carry.
check_headings() {
  awk -v file="${1#"$ROOT"/}" -v cap="$2" -v kind="$3" -v errors="$WORK/errors" \
    -v known="$WORK/known" -v borrowed="$WORK/borrowed" -v marks="$WORK/marks" '
    BEGIN { while ((getline line < known) > 0) live[line] = 1 }
    /^#/ { scenario = "" }
    kind == "main" && index($0, "- **NO E2E**") == 1 {
      if (scenario == "") printf "%s:%d: an exclusion belongs inside a scenario: %s\n", file, NR, $0 >> errors
      else printf "%s\t%s:%d\t%s\n", scenario, file, NR, $0 >> marks
    }
    /^#### Scenario:/ {
      name = substr($0, 16)
      ok = 0
      if (match(name, /^\[[a-z]+(-[a-z]+)*-[^]]*\] [^ ]/)) {
        id = substr(name, 2, index(name, "]") - 2)
        key = id; sub(/^.*-/, "", key)
        prefix = substr(id, 1, length(id) - length(key) - 1)
        ok = length(key) == 6 && key ~ /^[0-9a-f]+$/ && key ~ /[a-f]/
      }
      if (ok) scenario = id
      if (ok && prefix == cap) {
        if (kind == "main") print id, file
      } else if (ok && kind == "main" && (prefix in live)) {
        print id, file
      } else if (ok && kind == "change") {
        printf "%s %s:%d: %s\n", id, file, NR, $0 >> borrowed
      } else {
        printf "%s:%d: scenario must start with [%s-<hash>] from bin/scenario-id.sh %s: %s\n", file, NR, cap, cap, $0 >> errors
      }
    }
  ' "$1"
}

: > "$WORK/ids"
: > "$WORK/borrowed"
: > "$WORK/marks"
# Prefixes a moved scenario may keep: every live capability.
: > "$WORK/known"
if [ -d "$ROOT/openspec/specs" ]; then
  find "$ROOT/openspec/specs" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; > "$WORK/known"
fi
if [ -d "$ROOT/openspec/specs" ]; then
  while IFS= read -r file; do
    check_headings "$file" "$(basename "$(dirname "$file")")" main >> "$WORK/ids"
  done < <(find "$ROOT/openspec/specs" -name spec.md -type f | sort)
fi
if [ -d "$ROOT/openspec/changes" ]; then
  while IFS= read -r file; do
    check_headings "$file" "$(basename "$(dirname "$file")")" change
  done < <(find "$ROOT/openspec/changes" -path "$ROOT/openspec/changes/archive" -prune -o -path '*/specs/*' -name spec.md -type f -print | sort)
fi

cut -d' ' -f1 "$WORK/ids" | sort | uniq -d | while IFS= read -r id; do
  error "duplicate scenario ID: $id"
done
cut -d' ' -f1 "$WORK/ids" | sort -u > "$WORK/scenarios"

# A change's delta may carry another capability's ID only to move a scenario.
while IFS=' ' read -r id where; do
  grep -qx -- "$id" "$WORK/scenarios" && continue
  error "$where"$'\n'"  a new scenario takes an ID from bin/scenario-id.sh $(printf '%s' "$where" | sed -E 's|.*/specs/([^/]+)/spec\.md:.*|\1|')"
done < "$WORK/borrowed"

# Citations: the first ID in each bracket, in the black-box suites only. An ID
# ends at "]", "," or a space, so a hash is never cut short.
: > "$WORK/cited"
for dir in services/e2e/tests bin/tests; do
  [ -d "$ROOT/$dir" ] || continue
  grep -rhoE '\[[a-z]+(-[a-z]+)*-[0-9a-f]{6}[],[:space:]]' "$ROOT/$dir" \
    | sed -E 's/^\[//; s/.$//' >> "$WORK/cited" || true
done
sort -u -o "$WORK/cited" "$WORK/cited"

: > "$WORK/excluded"
while IFS=$'\t' read -r id where line; do
  rest="${line#"$MARK"}"
  rest="${rest# }"
  category="${rest%%:*}"
  reason="${rest#*:}"
  reason="${reason# }"
  case "$category" in
    internal-rule | not-built | external) ;;
    *) error "$where: expected '$MARK <category>: <reason>' with a category from $CATEGORIES: $line"; continue ;;
  esac
  if [ "$reason" = "$rest" ] || [ -z "$reason" ]; then
    error "$where: no reason given; expected '$MARK <category>: <reason>' with a category from $CATEGORIES: $line"
    continue
  fi
  if [ "$category" = internal-rule ]; then
    paths="$(printf '%s\n' "$reason" | grep -oE '(services|bin|infrastructure|\.claude/plugins)/[A-Za-z0-9._/-]*[A-Za-z0-9_]' || true)"
    if [ -z "$paths" ]; then
      error "$where: an internal-rule exclusion names the service test file that covers it: $line"
    fi
    for path in $paths; do
      [ -f "$ROOT/$path" ] || error "$where: $path does not exist"
    done
  fi
  if grep -qx -- "$id" "$WORK/excluded"; then
    error "$where: $id is excluded twice; keep one exclusion per scenario"
  fi
  echo "$id" >> "$WORK/excluded"
  if grep -qx -- "$id" "$WORK/cited"; then
    error "$where: $id is cited by an end-to-end test now; remove its exclusion"
  fi
done < "$WORK/marks"
sort -u -o "$WORK/excluded" "$WORK/excluded"

sort -u "$WORK/cited" "$WORK/excluded" | comm -23 "$WORK/scenarios" - > "$WORK/uncovered"
while IFS= read -r id; do
  error "not covered: $id ($(awk -v id="$id" '$1 == id { print $2; exit }' "$WORK/ids"))"
done < "$WORK/uncovered"

if [ -s "$WORK/errors" ]; then
  cat "$WORK/errors" >&2
  if [ -s "$WORK/uncovered" ]; then
    cat >&2 <<FIX

Each scenario needs an end-to-end test that cites it as [<id>] under
services/e2e/tests/ or bin/tests/, or, in its spec, a line
'$MARK <category>: <reason>' (categories: $CATEGORIES).
See bin/check-spec-coverage.sh --help.
FIX
  fi
  exit 1
fi

total="$(wc -l < "$WORK/scenarios" | tr -d ' ')"
excluded="$(comm -12 "$WORK/scenarios" "$WORK/excluded" | wc -l | tr -d ' ')"
echo "spec-coverage: $total scenarios: $((total - excluded)) cited, $excluded excluded"
