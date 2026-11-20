#!/usr/bin/env bash
# Fail on paths into one person's home directory in the files every teammate's
# agent reads: another machine has no such file, and agents stop on it.
#
#     bin/check-home-paths.sh            # the tracked files in scope
#     bin/check-home-paths.sh --staged   # the staged copies (pre-commit hook)
#     bin/check-home-paths.sh -          # standard input (a PR body)
#
# A personal home path is /Users/<name>, /home/<name> or <drive>:\Users\<name>,
# starting the text, a file:// URL, or after a character that cannot be part
# of a path, so src/pages/home/ and the placeholder /Users/<name>/ pass. Home-relative paths
# of the repository's own tooling, such as ~/.factory/sessions, pass too.
#
# In scope: openspec/ except openspec/changes/archive/, every AGENTS.md,
# CLAUDE.md and GEMINI.md, docs/, and the hand-written skills under
# .claude/skills/ (not the generated openspec-* ones). Prints
# <file>:<line>: <path> per hit and exits 1; exits 2 on bad arguments.
set -euo pipefail
export LC_ALL=C # grep matches and bash strips the boundary character byte by byte alike

usage() {
  echo "usage: bin/check-home-paths.sh [--staged | -]"
  echo
  sed -n '2,17p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

MODE=tree
case "${1:-}" in
  "") ;;
  --staged) MODE=staged ;;
  -) MODE=stdin ;;
  -h | --help) usage; exit 0 ;;
  *) usage >&2; exit 2 ;;
esac
[ $# -le 1 ] || { usage >&2; exit 2; }

# The character before the path cannot belong to a path; the name is one
# path segment. POSIX ERE, the same on BSD and GNU grep.
PATTERN='(^|[^A-Za-z0-9._~/-]|file://)(/(Users|home)/[A-Za-z0-9._-]+|[A-Za-z]:\\Users\\[A-Za-z0-9._-]+)'

in_scope() {
  case "$1" in
    openspec/changes/archive/*) return 1 ;;
    openspec/* | docs/*) return 0 ;;
    AGENTS.md | */AGENTS.md | CLAUDE.md | */CLAUDE.md | GEMINI.md | */GEMINI.md) return 0 ;;
    .claude/skills/openspec-*) return 1 ;;
    .claude/skills/*) return 0 ;;
    *) return 1 ;;
  esac
}

FOUND=0

# report <label>: read text on stdin and print every hit as <label>:<line>: <path>.
report() {
  local label="$1" line match
  while IFS= read -r hit; do
    line="${hit%%:*}"
    match="${hit#*:}"
    case "$match" in
      file://*) match="${match#file://}" ;;
      /* | [A-Za-z]:*) ;;
      *) match="${match:1}" ;;
    esac
    printf '%s:%s: %s\n' "$label" "$line" "$match"
    FOUND=1
  done < <(tr -d '\r' | grep -InoE "$PATTERN" || true)
}

if [ "$MODE" = stdin ]; then
  report '<stdin>'
else
  cd "$(git rev-parse --show-toplevel)"
  if [ "$MODE" = staged ]; then
    LIST=(git diff --cached --name-only -z --diff-filter=ACMR)
  else
    LIST=(git ls-files -z)
  fi
  while IFS= read -r -d '' path; do
    in_scope "$path" || continue
    if [ "$MODE" = staged ]; then
      report "$path" < <(git show ":$path")
    else
      [ -f "$path" ] || continue
      report "$path" < "./$path"
    fi
  done < <("${LIST[@]}")
fi

if [ "$FOUND" -eq 1 ]; then
  cat >&2 << 'FIX'

These paths point into one person's home directory, which no other machine has.
Name the file relative to the repository, or describe where it came from.
FIX
  exit 1
fi
