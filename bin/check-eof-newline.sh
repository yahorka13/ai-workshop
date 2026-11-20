#!/usr/bin/env bash
# Fail when a non-empty text file does not end with a newline.
#
#     bin/check-eof-newline.sh [--staged] <path>...
#
# --staged checks the copy in the index, i.e. what is about to be committed.
# Empty files, binary files (a NUL byte in the first 8000 bytes, git's own
# heuristic), symlinks, submodules and missing paths are skipped.
set -euo pipefail
# Byte-wise: tr and wc must not trip over binary content in a UTF-8 locale.
export LC_ALL=C

STAGED=0
if [ "${1:-}" = "--staged" ]; then
  STAGED=1
  shift
fi

is_regular_file() {
  if [ "$STAGED" -eq 1 ]; then
    case "$(git ls-files --stage -- ":(literal)$1")" in
      100644\ * | 100755\ *) return 0 ;;
      *) return 1 ;;
    esac
  else
    [ -f "$1" ] && [ ! -L "$1" ]
  fi
}

# Copy the content to a temp file first: piping a large file straight into
# `head` would die of SIGPIPE under pipefail.
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

bad=0
for path in "$@"; do
  is_regular_file "$path" || continue
  if [ "$STAGED" -eq 1 ]; then
    git cat-file blob ":./$path" > "$TMP"
  else
    cat -- "$path" > "$TMP"
  fi
  [ -s "$TMP" ] || continue
  if (( $(head -c 8000 "$TMP" | tr -d '\000' | wc -c) != $(head -c 8000 "$TMP" | wc -c) )); then
    continue
  fi
  if [ "$(tail -c 1 "$TMP" | od -An -tx1 | tr -d ' \n')" != "0a" ]; then
    echo "$path: missing newline at end of file" >&2
    bad=1
  fi
done
exit "$bad"
