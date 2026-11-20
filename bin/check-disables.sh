#!/usr/bin/env bash
# Fail if a service's count of one kind of marked exception differs from its
# committed baseline.
#
#     bin/check-disables.sh <kind> [<root>]
#
# Kinds, each with its mark and its baseline file:
#
#     duplicates  jscpd:ignore-start             bin/duplicate-disables.txt
#     unused      @knipignore, // knipignore:,   bin/unused-disables.txt
#                 @public or @beta (Knip hides the last two as well)
#     imports     // import-exception:           bin/import-disables.txt
#     mutations   // Stryker disable next-line      bin/mutation-disables.txt
#
# A mutations mark is an equivalent-mutant marker, in its one form:
#     // Stryker disable next-line <mutator>[,<mutator>...]: <reason>
# Any other Stryker disable comment fails, naming its file and line, and is
# not counted: one without next-line, without a named mutator, naming all, or
# without a reason.
#
# Counts every mark in the tracked .ts, .tsx, .js, .mjs and .cjs files of each
# services/<service>/ in <root> (default: this repository), and compares the
# count with that service's line in the kind's baseline file
# (`<service> <count>`). Generated code (src/generated/, contracts/, the ui's
# GraphQL types) is not counted. A rise fails and lists the service's marks; a
# fall fails until the lower count is committed, so the baseline only goes
# down. Exits 1 on a difference and 2 on bad arguments.
set -euo pipefail

usage() {
  echo "Usage: bin/check-disables.sh <kind> [<root>]"
  echo
  sed -n '2,3p;6,/^set /p' "${BASH_SOURCE[0]}" | sed '$d' | sed 's/^# \{0,1\}//'
}

if [ "${1:-}" = --help ]; then usage; exit 0; fi
[ $# -ge 1 ] && [ $# -le 2 ] || { usage >&2; exit 2; }
case "$1" in
  duplicates) PATTERN='jscpd:ignore-start' BASELINE=bin/duplicate-disables.txt NOUN='marked clones' ;;
  imports) PATTERN='// import-exception:' BASELINE=bin/import-disables.txt NOUN='import-rule exceptions' ;;
  unused) PATTERN='@knipignore|// knipignore:|@public|@beta' BASELINE=bin/unused-disables.txt NOUN='unused-code exceptions' ;;
  mutations) PATTERN='(//|/\*)[[:space:]]*Stryker disable[^*]*' BASELINE=bin/mutation-disables.txt NOUN='equivalent-mutant markers' ;;
  *) usage >&2; exit 2 ;;
esac
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${2:-$(git rev-parse --show-toplevel)}"

CODE=('services/*.ts' 'services/*.tsx' 'services/*.js' 'services/*.mjs' 'services/*.cjs')
GENERATED=(
  ':(exclude,glob)services/*/src/generated/**'
  ':(exclude,glob)services/*/contracts/**'
  ':(exclude,glob)services/ui/src/services/graphql/generated/**'
)

# Keeps the markers in their one form as `<path>:<line>` in $matches, and
# prints each other Stryker disable comment; returns 1 when there was one.
# Each input line is `<path>:<line>:<opener> <comment>`, where the opener is
# `//` or `/*`; a block comment is cut at its end and is never the one form.
valid_markers() {
  local match where text mutators invalid=0
  matches=""
  while IFS= read -r match; do
    [ -n "$match" ] || continue
    where="${match%%:*}"
    text="${match#*:}"
    where="$where:${text%%:*}"
    text="${text#*:}"
    text="${text%"${text##*[![:space:]]}"}"
    mutators="$(printf '%s' "$text" | sed -nE 's#^//[[:space:]]*Stryker disable next-line ([A-Za-z]+(,[A-Za-z]+)*): *[^ ].*$#\1#p')"
    text="$(printf '%s' "$text" | sed -E 's#^(//|/\*)[[:space:]]*##')"
    if [ -z "$mutators" ] || [[ ",$mutators," == *",all,"* ]]; then
      echo "$where: not // Stryker disable next-line <mutator>: <reason>: $text"
      invalid=1
    else
      matches="$matches$where"$'\n'
    fi
  done <<< "$1"
  return "$invalid"
}

found="$(git grep -n -o -I -E "$PATTERN" -- "${CODE[@]}" "${GENERATED[@]}" || true)"
status=0
if [ "$1" = mutations ]; then
  valid_markers "$found" || status=1
else
  # One `<path>:<line>` per mark.
  matches="$(printf '%s\n' "$found" | cut -d: -f1,2)"
fi
# shellcheck source=bin/suppressions.sh
. "$here/suppressions.sh"
compare_suppressions "$BASELINE" "$NOUN" "$matches" || status=1
exit "$status"
