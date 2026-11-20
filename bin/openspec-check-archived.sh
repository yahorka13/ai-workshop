#!/usr/bin/env bash
# Fail when an OpenSpec change of a change branch's issue has not been archived.
#
#     bin/openspec-check-archived.sh 1096-a3f9c1-referral-credits
#
# One issue is one branch and one PR: every change of the issue is built on the
# branch named after its first change, and each change's deltas must land in
# openspec/specs/ in that same PR. So by the time the PR is ready for review,
# every change folder of the issue must have moved to
# openspec/changes/archive/. Branches that are not change branches (plain
# issue branches, hotfixes) pass untouched.
set -euo pipefail

BRANCH="${1:?usage: $0 <branch>}"
ROOT="${OPENSPEC_ROOT:-$(git rev-parse --show-toplevel)}"
CHANGES="$ROOT/openspec/changes"

if ! [[ "$BRANCH" =~ ^([0-9]+)-[0-9a-f]{6}- ]]; then
  echo "Not a change branch: $BRANCH - nothing to check."
  exit 0
fi
ISSUE="${BASH_REMATCH[1]}"

active=0
for dir in "$CHANGES/$ISSUE"-*/; do
  [ -d "$dir" ] || continue
  change="$(basename "$dir")"
  [[ "$change" =~ ^$ISSUE-[0-9a-f]{6}- ]] || continue
  echo "::error::Change $change is not archived. Run /work-pr (or bin/openspec-archive $change) before marking the PR ready." >&2
  active=1
done
[ "$active" = 0 ] || exit 1

if ! compgen -G "$CHANGES/archive/*-$BRANCH" >/dev/null; then
  echo "::error::No change folder for $BRANCH in openspec/changes/ or openspec/changes/archive/. Change branches must carry their OpenSpec change." >&2
  exit 1
fi

echo "Change $BRANCH is archived."
