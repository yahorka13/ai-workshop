#!/usr/bin/env bash
# Print the commit-subject prefix a branch dictates, or nothing.
#
#     bin/commit-prefix.sh 12-a3f9c1-session-slots   → [12][a3f9c1]
#     bin/commit-prefix.sh 12-fix-typo               → [12]
#     bin/commit-prefix.sh hotfix-login              → (nothing)
#
# Used by bin/check-commit-subject.sh and the prepare-commit-msg hook, so the
# branch rule lives in one place. See AGENTS.md → "Commit messages".
set -euo pipefail
LC_COLLATE=C

[ $# -eq 1 ] || { echo "usage: $0 <branch>" >&2; exit 2; }

change_re='^([0-9]+)-([0-9a-f]{6})-'
issue_re='^([0-9]+)-'

if [[ "$1" =~ $change_re ]]; then
  echo "[${BASH_REMATCH[1]}][${BASH_REMATCH[2]}]"
elif [[ "$1" =~ $issue_re ]]; then
  echo "[${BASH_REMATCH[1]}]"
fi
