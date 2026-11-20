#!/usr/bin/env bash
# CI's eof-newline step: check the files a pull request or a push changed for
# a final newline (bin/check-eof-newline.sh).
#
#     bin/ci-eof-newline.sh <base> <head>
#
# Checks the files added, copied, modified or renamed in <base>...<head>. With
# an empty or all-zero <base>, as on the first push to a fresh copy's main,
# checks every file tracked at <head>.
set -euo pipefail

case "${1:-}" in
  -h | --help) sed -n '2,9p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac
[ $# -eq 2 ] || { echo "usage: bin/ci-eof-newline.sh <base> <head>" >&2; exit 2; }
BASE="$1"
HEAD="$2"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

LIST="$(mktemp)"
trap 'rm -f "$LIST"' EXIT
if [[ "$BASE" =~ ^0*$ ]]; then
  git ls-tree -r -z --name-only "$HEAD" > "$LIST"
else
  git diff --name-only -z --diff-filter=ACMR "$BASE...$HEAD" > "$LIST"
fi
[ -s "$LIST" ] || exit 0
xargs -0 "$HERE/check-eof-newline.sh" < "$LIST"
