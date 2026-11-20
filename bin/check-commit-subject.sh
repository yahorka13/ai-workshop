#!/usr/bin/env bash
# Check one commit subject against AGENTS.md → "Commit messages".
#
#     bin/check-commit-subject.sh [--allow-fixup] <branch> <subject>
#
# The branch dictates the prefix (bin/commit-prefix.sh): [N][hash] on a change
# branch, [N] on an issue branch, and [N], [N][hash] or [HOTFIX] on any other
# branch. On a change branch another change's hash is also accepted when that
# change belongs to the same issue and exists in openspec/changes, so a branch
# that merged a sibling change keeps its commits' own attribution.
#
# Then an optional lowercase "<scope>: ", then an uppercase letter, at most 72
# characters in all. fixup!/squash! subjects fail unless --allow-fixup
# is given: the local commit-msg hook allows them, CI does not.
set -euo pipefail
LC_COLLATE=C

MAX_LENGTH=72
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  echo "usage: $0 [--allow-fixup] <branch> <subject>" >&2
  exit 2
}

ALLOW_FIXUP=0
if [ "${1:-}" = "--allow-fixup" ]; then
  ALLOW_FIXUP=1
  shift
fi
[ $# -eq 2 ] || usage
BRANCH="$1"
SUBJECT="$2"

reject() {
  echo "Bad commit subject: $SUBJECT" >&2
  echo "  $1" >&2
  exit 1
}

fixup_re='^(fixup|squash|amend)! '
if [[ "$SUBJECT" =~ $fixup_re ]]; then
  [ "$ALLOW_FIXUP" -eq 0 ] || exit 0
  reject "fixup!/squash!/amend! commits must be squashed before merge: git rebase --autosquash <base>"
fi

PREFIX="$("$HERE/commit-prefix.sh" "$BRANCH")"
any_prefix_re='^(\[HOTFIX\]|\[[0-9]+\](\[[0-9a-f]{6}\])?) '

# A change of this issue that this repository knows about, active or archived.
sibling_change() {
  local issue="$1" hash="$2" root
  root="$(git rev-parse --show-toplevel 2>/dev/null || echo "$HERE/..")"
  compgen -G "$root/openspec/changes/$issue-$hash-*" > /dev/null && return 0
  compgen -G "$root/openspec/changes/archive/*-$issue-$hash-*" > /dev/null && return 0
  return 1
}

if [ -n "$PREFIX" ]; then
  sibling_re='^\[([0-9]+)\]\[([0-9a-f]{6})\] '
  if [[ "$SUBJECT" == "$PREFIX "* ]]; then
    REST="${SUBJECT#"$PREFIX "}"
  elif [[ "$SUBJECT" =~ $sibling_re ]] &&
    [ "[${BASH_REMATCH[1]}]" = "${PREFIX%%\]*}]" ] &&
    sibling_change "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"; then
    REST="${SUBJECT#"${BASH_REMATCH[0]}"}"
  else
    reject "expected subject to start with \"$PREFIX \" on branch $BRANCH, or with another change of that issue that exists in openspec/changes"
  fi
elif [[ "$SUBJECT" =~ $any_prefix_re ]]; then
  REST="${SUBJECT#"${BASH_REMATCH[0]}"}"
else
  reject "expected subject to start with \"[<issue>] \", \"[<issue>][<hash>] \" or \"[HOTFIX] \""
fi

scope_re='^[[:lower:][:digit:]][[:lower:][:digit:]-]*: '
if [[ "$REST" =~ $scope_re ]]; then
  REST="${REST#"${BASH_REMATCH[0]}"}"
fi

upper_re='^[[:upper:]]'
[[ "$REST" =~ $upper_re ]] || reject "description must start with an uppercase letter (sentence case, imperative): \"$REST\""

[ "${#SUBJECT}" -le "$MAX_LENGTH" ] || reject "subject is ${#SUBJECT} characters; the limit is $MAX_LENGTH"
