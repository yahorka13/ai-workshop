#!/usr/bin/env bash
# Check the subject of every non-merge commit in <base>..<head>.
#
#     bin/check-commit-range.sh <branch> <base> <head>
#
# CI runs this over a pull request's commits. Every bad subject is reported,
# not just the first, and fixup!/squash! commits are rejected. Only the
# first-parent chain is checked: history a merge brings in (an imported
# subtree, main merged into the branch) was not written on this branch.
set -euo pipefail

[ $# -eq 3 ] || { echo "usage: $0 <branch> <base> <head>" >&2; exit 2; }
BRANCH="$1"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# A separate assignment, so an unknown revision stops the script.
COMMITS="$(git log --first-parent --no-merges --format='%h %s' "$2..$3")"

total=0
bad=0
while IFS= read -r line; do
  [ -n "$line" ] || continue
  total=$((total + 1))
  sha="${line%% *}"
  subject="${line#* }"
  if ! error="$("$HERE/check-commit-subject.sh" "$BRANCH" "$subject" 2>&1)"; then
    echo "$sha: $error"
    bad=$((bad + 1))
  fi
done <<< "$COMMITS"

if [ "$bad" -gt 0 ]; then
  echo "$bad of $total commit subjects are malformed. Rewriting pushed commits is a human's call: ask a human before rewording them." >&2
  exit 1
fi
echo "Checked $total commit subjects."
