#!/usr/bin/env bash
# CI's issue-closed job: remove the "in progress" label that bin/issue-start
# sets, so a closed issue does not read as being worked on. An issue without
# the label is left alone.
#
#     bin/ci-issue-closed.sh <issue-number>
#
# Needs `gh` with GH_TOKEN and GH_REPO set.
set -euo pipefail

[ $# -eq 1 ] || { echo "usage: $0 <issue-number>" >&2; exit 2; }
ISSUE="$1"
LABEL='in progress'

LABELS="$(gh issue view "$ISSUE" --json labels --jq '.labels[].name')"
if grep -qxF -- "$LABEL" <<< "$LABELS"; then
  gh issue edit "$ISSUE" --remove-label "$LABEL" > /dev/null
  echo "Removed \"$LABEL\" from issue #$ISSUE."
else
  echo "Issue #$ISSUE has no \"$LABEL\" label."
fi
