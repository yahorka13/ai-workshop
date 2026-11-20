#!/usr/bin/env bash
# Fail if a service's lint suppressions differ from the committed baseline.
#
#     bin/check-lint-disables.sh [<root>]
#
# Counts every eslint-disable and @ts-expect-error in the tracked .ts, .tsx,
# .js, .mjs and .cjs files of each services/<service>/ in <root> (default: this
# repository), and compares the count with that service's line in
# bin/lint-disables.txt (`<service> <count>`). Generated code (src/generated/,
# contracts/, the ui's GraphQL types) is not counted. A rise fails and lists the service's suppressions; a fall fails
# until the lower count is committed, so the baseline only goes down.
#
# Violations cannot be frozen either: any tracked eslint-suppressions.json
# under services/, which ESLint would read, fails with its path. Exits 1 on a
# difference or such a file and 2 on bad arguments.
set -euo pipefail

usage() {
  echo "Usage: bin/check-lint-disables.sh [<root>]"
  echo
  sed -n '2,3p;6,/^set /p' "${BASH_SOURCE[0]}" | sed '$d' | sed 's/^# \{0,1\}//'
}

if [ "${1:-}" = --help ]; then usage; exit 0; fi
[ $# -le 1 ] || { usage >&2; exit 2; }
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${1:-$(git rev-parse --show-toplevel)}"

BASELINE=bin/lint-disables.txt
PATTERN='eslint-disable|@ts-expect-error'
CODE=('services/*.ts' 'services/*.tsx' 'services/*.js' 'services/*.mjs' 'services/*.cjs')
GENERATED=(
  ':(exclude,glob)services/*/src/generated/**'
  ':(exclude,glob)services/*/contracts/**'
  ':(exclude,glob)services/ui/src/services/graphql/generated/**'
)

# One `<path>:<line>` per suppression.
matches="$(git grep -n -o -I -E "$PATTERN" -- "${CODE[@]}" "${GENERATED[@]}" | cut -d: -f1,2 || true)"
# shellcheck source=bin/suppressions.sh
. "$here/suppressions.sh"
status=0
compare_suppressions "$BASELINE" suppressions "$matches" || status=1
while read -r file; do
  echo "$file: tracked lint suppressions file; fix the violations and delete it"
  status=1
done < <(git ls-files -- 'services/*/eslint-suppressions.json')
exit "$status"
