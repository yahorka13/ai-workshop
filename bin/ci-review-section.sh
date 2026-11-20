#!/usr/bin/env bash
# CI's review-section check: fail a ready pull request whose description has
# no `## Review` section, or only blank lines under it; let drafts pass.
#
#     bin/ci-review-section.sh <pr-number>
#
# The section lists every finding of the independent agent review with its
# outcome, or says "No findings." (AGENTS.md, "Pull requests"). The draft
# state and the description are read from GitHub when the check runs, not
# from the event that started it, so an edited description is checked as it
# is now. If they cannot be read, the check fails. Needs `gh` with GH_TOKEN
# and GH_REPO set.
set -euo pipefail

[ $# -eq 1 ] || { echo "usage: $0 <pr-number>" >&2; exit 2; }
PR="$1"

IS_DRAFT="$(gh pr view "$PR" --json isDraft --jq .isDraft)"
if [ "$IS_DRAFT" = true ]; then
  echo "PR #$PR is a draft - the review is checked once it is ready for review."
  exit 0
fi

BODY="$(gh pr view "$PR" --json body --jq .body)"

# missing: no `## Review` heading; empty: only blank lines before the next
# `## ` heading or the end; ok: at least one other line.
STATE="$(printf '%s\n' "$BODY" | tr -d '\r' | awk '
  /^## Review[[:space:]]*$/ { inside = 1; found = 1; next }
  inside && /^## / { inside = 0 }
  inside && /[^[:space:]]/ { content = 1 }
  END { if (!found) print "missing"; else if (!content) print "empty"; else print "ok" }
')"

case "$STATE" in
  missing)
    echo "PR #$PR has no \`## Review\` section: list every finding of the agent review with its outcome, or \"No findings.\"" >&2
    exit 1
    ;;
  empty)
    echo "PR #$PR: the \`## Review\` section is empty: list every finding of the agent review with its outcome, or \"No findings.\"" >&2
    exit 1
    ;;
esac
echo "PR #$PR records its review."
