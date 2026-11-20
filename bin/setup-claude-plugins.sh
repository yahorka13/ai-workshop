#!/usr/bin/env bash
# Install the Claude Code plugins .claude/settings.json declares, and Orca's
# orca-cli skill when Orca is present. Safe to run again.
#
#     bin/setup-claude-plugins.sh
#
# Without claude on PATH (CI, another agent) the plugins are skipped. Each
# declared plugin Claude Code does not list as installed for this checkout (an
# install for another worktree does not count) is installed at project scope, and
# a failed install fails. A plugin's host binary must be on PATH: the fix is printed, and nothing global
# is installed. A declared plugin also enabled from another marketplace loads
# twice: the disable command is printed. With orca on PATH, a missing orca-cli
# skill is installed through Orca; it is optional, so a failure only warns.
# Restart a running Claude Code session to load them.
set -euo pipefail

usage() {
  echo "Usage: bin/setup-claude-plugins.sh"
  echo
  sed -n '2,3p;6,/^set /p' "${BASH_SOURCE[0]}" | sed '$d' | sed 's/^# \{0,1\}//'
}

if [ "${1:-}" = --help ]; then usage; exit 0; fi
[ $# -eq 0 ] || { usage >&2; exit 2; }

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

# The host binary a declared plugin runs, and how to get it: <plugin>|<binary>|<fix>
HOST_BINARIES='playwright|npx|install Node.js (https://nodejs.org), which ships npx'

# Plugin ids .claude/settings.json enables, one per line.
declared() {
  grep -oE '"[a-z0-9-]+@[a-z0-9-]+": *true' "$ROOT/.claude/settings.json" | cut -d'"' -f2
}

# Prints "<id> <true|false>" for each plugin `claude plugin list --json` lists
# as installed for this checkout. It lists project- and local-scope installs of
# every project, each with its projectPath; only those for $ROOT count here.
installed() {
  # shellcheck disable=SC2020 # each of the three characters becomes a newline
  claude plugin list --json | tr ',{}' '\n\n\n' | awk -F'"' -v root="$ROOT" '
    function emit() { if (id != "" && (scope == "user" || scope == "managed" || path == root)) print id, enabled }
    $2 == "id" { emit(); id = $4; scope = ""; path = ""; enabled = "false" }
    $2 == "scope" { scope = $4 }
    $2 == "projectPath" { path = $4 }
    $2 == "enabled" { enabled = ($3 ~ /true/ ? "true" : "false") }
    END { emit() }'
}

install_plugins() {
  local list id name plugin binary fix other missing=0
  list="$(installed)"
  for id in $(declared); do
    while IFS='|' read -r plugin binary fix; do
      [ "$plugin" = "${id%@*}" ] || continue
      command -v "$binary" > /dev/null 2>&1 && continue
      echo "$plugin needs $binary on PATH: $fix" >&2
      missing=1
    done <<< "$HOST_BINARIES"
  done
  [ "$missing" -eq 0 ] || exit 1
  for id in $(declared); do
    name="${id%@*}"
    if grep -q "^$id " <<< "$list"; then
      echo "$id: installed"
    else
      claude plugin install "$id" --scope project || { echo "could not install $id" >&2; exit 1; }
    fi
    while read -r other _; do
      [ -n "$other" ] && [ "$other" != "$id" ] || continue
      echo "warning: $name loads twice, from $other too; run: claude plugin disable $other" >&2
    done < <(grep -E "^$name@[a-z0-9-]+ true$" <<< "$list" || true)
  done
}

install_orca_cli() {
  if orca skills installed --json 2> /dev/null | grep -qE '"name": *"orca-cli"'; then
    echo "orca-cli: installed"
  elif ! orca skills install --skill orca-cli; then
    echo "warning: orca-cli is not installed; run: orca skills install --skill orca-cli" >&2
  fi
}

if command -v claude > /dev/null 2>&1; then
  install_plugins
else
  echo "claude not on PATH: skipping the Claude Code plugins"
fi
if command -v orca > /dev/null 2>&1; then
  install_orca_cli
fi
