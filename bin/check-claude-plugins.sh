#!/usr/bin/env bash
# Fail if the workflow's instructions name a plugin skill whose plugin
# .claude/settings.json does not enable.
#
#     bin/check-claude-plugins.sh [<root>]
#
# Scans every AGENTS.md, openspec/schemas/ and the hand-written skills in
# .claude/skills/work and .claude/skills/work-pr for `<plugin>:<skill>` and
# **<plugin>:<skill>**. A token that names a script in a service's package.json
# is not a skill. Checks the plugin, not the skill: CI has no plugins
# installed. Exits 1 on an undeclared plugin and 2 on bad arguments.
set -euo pipefail

usage() {
  echo "Usage: bin/check-claude-plugins.sh [<root>]"
  echo
  sed -n '2,3p;6,/^set /p' "${BASH_SOURCE[0]}" | sed '$d' | sed 's/^# \{0,1\}//'
}

if [ "${1:-}" = --help ]; then usage; exit 0; fi
[ $# -le 1 ] || { usage >&2; exit 2; }
cd "${1:-$(git rev-parse --show-toplevel)}"

declared="$(grep -oE '"[a-z0-9-]+@[a-z0-9-]+": *true' .claude/settings.json 2> /dev/null | cut -d'"' -f2 | cut -d@ -f1 || true)"
scripts="$(find services -maxdepth 2 -name package.json -exec cat {} + 2> /dev/null | grep -oE '"[a-z0-9-]+:[a-z0-9-]+": *"' | cut -d'"' -f2 || true)"

files=()
while IFS= read -r -d '' file; do
  files+=("${file#./}")
done < <(find . \( -name node_modules -o -name .git \) -prune -o -name AGENTS.md -print0 \
  -o -path ./openspec/schemas -prune -print0 -o \( -path ./.claude/skills/work -o -path ./.claude/skills/work-pr \) -prune -print0)

# shellcheck disable=SC2016 # literal backticks of markdown skill references
REFERENCE='(`|\*\*)[a-z][a-z0-9-]*:[a-z][a-z0-9-]*(`|\*\*)'
bad=0
while IFS= read -r hit; do
  [ -n "$hit" ] || continue
  file="${hit%%:*}"
  rest="${hit#*:}"
  line="${rest%%:*}"
  ref="${rest#*:}"
  ref="${ref//\`/}"
  ref="${ref//\*/}"
  grep -qxF "$ref" <<< "$scripts" && continue
  grep -qxF "${ref%%:*}" <<< "$declared" && continue
  echo "$file:$line: $ref names plugin ${ref%%:*}, which .claude/settings.json does not enable" >&2
  bad=1
done < <([ "${#files[@]}" -eq 0 ] || grep -rHnoE "$REFERENCE" "${files[@]}" || true)

if [ "$bad" -eq 1 ]; then
  echo "Enable the plugin in .claude/settings.json, or name a skill the repository has." >&2
  exit 1
fi
echo "every plugin skill the workflow names comes from a plugin .claude/settings.json enables"
