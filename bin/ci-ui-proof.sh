#!/usr/bin/env bash
# CI's ui-proof check: a ready pull request that changes the ui's shipped code,
# services/ui/src/, shows an image or a video of the change in its "## Proof"
# section. Tests, tooling and configuration need none, and so do
# the files bin/contracts generate writes there from the backend's contracts,
# which show nothing.
#
#     bin/ci-ui-proof.sh <pr-number>
#
# Reads the PR from GitHub when the check runs, like bin/ci-change-archived.sh:
# drafts pass, and a state that cannot be read fails the check. Proof is a
# markdown image, an <img> or <video> tag, a link to a .png, .jpg, .gif, .webm
# or .mp4 file, or a GitHub upload (github.com/user-attachments/...). Needs
# `gh` with GH_TOKEN and GH_REPO set.
set -euo pipefail

[ $# -eq 1 ] || { echo "usage: $0 <pr-number>" >&2; exit 2; }
PR="$1"

IS_DRAFT="$(gh pr view "$PR" --json isDraft --jq .isDraft)"
if [ "$IS_DRAFT" = true ]; then
  echo "PR #$PR is a draft - its proof is checked once it is ready for review."
  exit 0
fi

# The folder generation owns, the ui's graphqlTypesRoot in
# services/ui/tooling/contracts-render.ts; bin/check ui fails a hand edit there.
generated='^services/ui/src/services/graphql/generated/'

# Paginated: gh pr view lists only a PR's first 100 files.
FILES="$(gh api --paginate "repos/{owner}/{repo}/pulls/$PR/files" --jq '.[].path')"
if ! grep -q '^services/ui/src/' <<<"$FILES"; then
  echo "PR #$PR changes nothing under services/ui/src/ - no visual proof required."
  exit 0
fi
# Read whole, not with grep -q in a pipe, which can cut off its writer.
HAND_WRITTEN="$(grep '^services/ui/src/' <<<"$FILES" | grep -vE "$generated" || true)"
if [ -z "$HAND_WRITTEN" ]; then
  echo "PR #$PR changes only generated files under services/ui/src/ - no visual proof required."
  exit 0
fi

BODY="$(gh pr view "$PR" --json body --jq .body)"
PROOF="$(printf '%s\n' "$BODY" | tr -d '\r' | awk '/^## / { inside = ($0 ~ /^## Proof[[:space:]]*$/); next } inside')"
media='!\[[^]]*\]\([^)]+\)|<img[[:space:]]|<video[[:space:]]|\.(png|jpe?g|gif|webm|mp4)([?#][^)[:space:]]*)?([)[:space:]"]|$)|github\.com/user-attachments/'
if grep -qiE "$media" <<<"$PROOF"; then
  echo "PR #$PR changes services/ui/src/ and its ## Proof section shows it."
  exit 0
fi

cat >&2 <<FIX
::error::PR #$PR changes services/ui/src/ but its ## Proof section has no screenshot or recording.
Capture the change on your stack with bin/e2e --proof (commit the files it
writes), push, then paste the output of bin/proof-markdown HEAD into the PR's
## Proof section. Editing the description reruns this check.
FIX
exit 1
