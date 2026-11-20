#!/usr/bin/env bash
# Fail on writing conventions AGENTS.md states, in the tracked files of <root>
# (default: this repository):
#
#   superpowers    a file under docs/superpowers/: designs go to the change's
#                  design.md, plans to its tasks.md
#   quoted-number  a YAML (*.yml, *.yaml) or env (*.env, .env*) value that is a
#                  quoted number and reads back as the same number unquoted;
#                  values YAML would misread, such as "0123" or "3.10", stay,
#                  and so does a value a schema needs as a string, marked on
#                  its line with # string: <reason>; the content of a YAML
#                  block scalar (a value after | or >) is text, not a value
#   gh-repo        a gh command other than gh api, in an AGENTS.md, a
#                  hand-written skill (.claude/skills/*/SKILL.md) or the
#                  OpenSpec schema, without -R "$(bin/repo)" (or
#                  --repo "$(bin/repo)"); each command on a line is checked on its own
#
#     bin/check-conventions.sh [<root>]
#
# Prints <file>:<line>: <rule> and its fix per hit, then exits 1; exits 2 on
# bad arguments.
set -euo pipefail

usage() {
  echo "usage: bin/check-conventions.sh [<root>]"
  echo
  sed -n '2,19p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

case "${1:-}" in
  -h | --help) usage; exit 0 ;;
esac
[ $# -le 1 ] || { usage >&2; exit 2; }
ROOT="${1:-$(git rev-parse --show-toplevel)}"
[ -d "$ROOT" ] || { echo "bin/check-conventions.sh: no such directory: $ROOT" >&2; exit 2; }

# A number as YAML reads it back unchanged: no leading zero, no trailing
# decimal zero. Two patterns per quote, as BSD grep has no backreferences.
NUMBER='-?(0|[1-9][0-9]*)(\.[0-9]*[1-9])?'
TAIL='[[:space:]]*(#.*)?$'
YAML_DOUBLE="(:|^[[:space:]]*-)[[:space:]]+\"$NUMBER\"$TAIL"
YAML_SINGLE="(:|^[[:space:]]*-)[[:space:]]+'$NUMBER'$TAIL"
ENV_DOUBLE="^[A-Za-z_][A-Za-z0-9_]*=\"$NUMBER\"$TAIL"
ENV_SINGLE="^[A-Za-z_][A-Za-z0-9_]*='$NUMBER'$TAIL"
# The gh commands that act on a repository and take -R; gh api names the
# repository in its path, and account commands such as gh auth take none.
GH_COMMAND='(^|[^A-Za-z0-9_./-])gh[[:space:]]+(attestation|browse|cache|co|issue|label|pr|release|repo|ruleset|run|search|secret|variable|workflow)([^A-Za-z0-9_-].*)?$'

FOUND=0

hit() {
  echo "$1: $2"
  FOUND=1
}

# yaml_values <file>: the file with the content of every block scalar (a value
# after | or >, such as a step's script) blanked, so line numbers stay.
yaml_values() {
  awk '
    block {
      match($0, /^ */)
      if ($0 ~ /^[[:space:]]*$/ || RLENGTH > indent) { print ""; next }
      block = 0
    }
    { print }
    /(:|^[[:space:]]*-)[[:space:]]+[|>][-+0-9]*[[:space:]]*(#.*)?$/ { block = 1; match($0, /^ */); indent = RLENGTH }
  ' "$1"
}

# lines <filter> <file> <pattern>...: the line numbers of the filtered file
# matching any pattern.
lines() {
  local filter="$1" file="$2"
  shift 2
  local args=() pattern
  for pattern in "$@"; do args+=(-e "$pattern"); done
  "$filter" "$ROOT/$file" | grep -nE "${args[@]}" | grep -vE '#[[:space:]]*string:[[:space:]]*[^[:space:]]' | cut -d: -f1 || true
}

# gh_without_repo <text>: whether a gh command in the text, up to the next
# one, names no repository.
gh_without_repo() {
  local rest="$1" command
  while [[ "$rest" =~ $GH_COMMAND ]]; do
    rest="${BASH_REMATCH[3]}"
    command="$rest"
    [[ "$rest" =~ $GH_COMMAND ]] && command="${rest%"${BASH_REMATCH[0]}"}"
    case "$command" in
      *"-R \"\$(bin/repo)\""* | *"--repo \"\$(bin/repo)\""* | *"--repo=\"\$(bin/repo)\""*) ;;
      *) return 0 ;;
    esac
  done
  return 1
}

while IFS= read -r -d '' path; do
  case "$path" in
    docs/superpowers/*)
      hit "$path" "superpowers: write the design to the change's design.md and the plan to its tasks.md, not docs/superpowers/"
      continue
      ;;
  esac
  [ -f "$ROOT/$path" ] || continue
  case "$path" in
    *.yml | *.yaml)
      for line in $(lines yaml_values "$path" "$YAML_DOUBLE" "$YAML_SINGLE"); do
        hit "$path:$line" "quoted-number: write the number unquoted; quote only values YAML would misread, such as 0123, or mark a value a schema needs as a string with # string: <reason>"
      done
      ;;
    *.env | .env* | */.env*)
      for line in $(lines cat "$path" "$ENV_DOUBLE" "$ENV_SINGLE"); do
        hit "$path:$line" "quoted-number: write the number unquoted, or mark a value that must stay a string with # string: <reason>"
      done
      ;;
  esac
  case "$path" in
    .claude/skills/openspec-*) ;;
    AGENTS.md | */AGENTS.md | .claude/skills/*/SKILL.md | openspec/schemas/*)
      while IFS=: read -r line text; do
        if gh_without_repo "$text"; then
          hit "$path:$line" "gh-repo: pass -R \"\$(bin/repo)\" to every gh command: a literal repository breaks every copy of the template"
        fi
      done < <(grep -nE -- "$GH_COMMAND" "$ROOT/$path" || true)
      ;;
  esac
done < <(git -C "$ROOT" ls-files -z)

[ "$FOUND" -eq 0 ] || exit 1
