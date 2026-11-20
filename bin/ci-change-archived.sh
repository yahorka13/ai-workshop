#!/usr/bin/env bash
# CI's change-archived check: fail a ready pull request whose OpenSpec change
# is not archived; let drafts pass.
#
#     bin/ci-change-archived.sh <pr-number> <branch>
#
# The draft state is read from GitHub when the check runs, not from the event
# that started it: a push and "ready for review" seconds apart can leave the
# event saying "draft" for the commit that ends up under review. If the state
# cannot be read, the check fails. Needs `gh` with GH_TOKEN and GH_REPO set.
set -euo pipefail

[ $# -eq 2 ] || { echo "usage: $0 <pr-number> <branch>" >&2; exit 2; }
PR="$1"
BRANCH="$2"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

IS_DRAFT="$(gh pr view "$PR" --json isDraft --jq .isDraft)"
if [ "$IS_DRAFT" = true ]; then
  echo "PR #$PR is a draft - the archive is checked once it is ready for review."
  exit 0
fi

exec "$HERE/openspec-check-archived.sh" "$BRANCH"
