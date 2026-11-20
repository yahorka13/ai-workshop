#!/usr/bin/env bash
# CI's pr-body check: a pull request's title and body follow AGENTS.md →
# "Pull requests".
#
#     bin/ci-pr-body.sh <pr-number>
#
# Reads the PR from GitHub when the check runs, drafts included, and reports
# every broken rule in one run as a ::error:: line with its fix:
#   - the title starts with the prefix the head branch dictates
#     (bin/commit-prefix.sh): [N][hash] on a change branch, [N] on an issue
#     branch, [N], [N][hash] or [HOTFIX] on any other; then a capital letter or
#     a lowercase "<scope>: ". Titles have no length limit;
#   - the body has ## Summary, ## Changes and ## Proof in that order (other
#     sections may sit between them) and a "Closes #N" line for the title's
#     issue, except on a [HOTFIX] title;
#   - one "Change: `<id>`" line for each change of the issue the PR's diff
#     adds or edits, active or archived, and none for a change it leaves
#     alone. The diff runs from the checkout's HEAD, which must be the PR's
#     head, and needs the base commit (full history);
#   - no heading mentions a test plan, and no heredoc was pasted in (a line
#     that is only EOF, or "$(cat <<", outside a ``` code block);
#   - the body names no path in one person's home directory
#     (bin/check-home-paths.sh).
# The ## Review section is the review-section check's (bin/ci-review-section.sh):
# it applies to ready pull requests only, and this check to drafts too.
# Needs `gh` with GH_TOKEN and GH_REPO set, and `jq`. Exits 1 on a broken
# rule, 2 on bad arguments; a PR that cannot be read fails the check.
set -euo pipefail

usage() {
  echo "usage: bin/ci-pr-body.sh <pr-number>"
  echo
  sed -n '7,/^set /p' "${BASH_SOURCE[0]}" | sed '$d' | sed 's/^# \{0,1\}//'
}

case "${1:-}" in
  -h | --help) usage; exit 0 ;;
esac
[ $# -eq 1 ] && [[ "$1" =~ ^[0-9]+$ ]] || { usage >&2; exit 2; }
PR="$1"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PR_JSON="$(gh pr view "$PR" --json title,body,headRefName,baseRefOid)"
TITLE="$(jq -r .title <<< "$PR_JSON")"
BRANCH="$(jq -r .headRefName <<< "$PR_JSON")"
BASE="$(jq -r .baseRefOid <<< "$PR_JSON")"
BODY="$(jq -r .body <<< "$PR_JSON" | tr -d '\r')"

ERRORS=()
ISSUE="" # from the title's prefix; empty for [HOTFIX]

check_title() {
  local prefix rest
  prefix="$("$HERE/commit-prefix.sh" "$BRANCH")"
  if [ -n "$prefix" ]; then
    if [ "${TITLE#"$prefix "}" = "$TITLE" ]; then
      ERRORS+=("The title must start with $prefix, the prefix branch $BRANCH dictates, then a space: \"$prefix <Description>\".")
      return
    fi
  elif [[ "$TITLE" =~ ^(\[[0-9]+\](\[[0-9a-f]{6}\])?|\[HOTFIX\])\  ]]; then
    prefix="${BASH_REMATCH[1]}"
  else
    ERRORS+=("The title must start with [<issue>], [<issue>][<hash>] or [HOTFIX], then a space.")
    return
  fi
  rest="${TITLE#"$prefix "}"
  [[ "$prefix" =~ ^\[([0-9]+)\] ]] && ISSUE="${BASH_REMATCH[1]}"
  [[ "$rest" =~ ^([a-z0-9-]+:\ )?[A-Z] ]] ||
    ERRORS+=("After its prefix the title starts with a capital letter, or a lowercase \"<scope>: \" and then one: \"$prefix Allocate session slots\".")
}

check_sections() {
  local headings want next=0 missing=()
  headings="$(printf '%s\n' "$BODY" | sed -nE 's/^## +(.*[^[:space:]])[[:space:]]*$/\1/p')"
  for want in Summary Changes Proof; do
    grep -qx "$want" <<< "$headings" || missing+=("## $want")
  done
  if [ "${#missing[@]}" -gt 0 ]; then
    ERRORS+=("The body has no ${missing[*]} section. It needs ## Summary, ## Changes and ## Proof; /work-pr has the template.")
    return
  fi
  while IFS= read -r want; do
    case "$next:$want" in
      0:Summary) next=1 ;;
      1:Changes) next=2 ;;
      2:Proof) next=3 ;;
    esac
  done <<< "$headings"
  [ "$next" -eq 3 ] || ERRORS+=("The body's sections must be ## Summary, ## Changes and ## Proof, in that order.")
}

check_issue_line() {
  [ -n "$ISSUE" ] || return 0
  grep -qE "^Closes #${ISSUE}([^0-9]|$)" <<< "$BODY" ||
    ERRORS+=("The body has no \"Closes #$ISSUE\" line. Add it under ## Summary so merging closes the issue.")
}

check_change_lines() {
  local touched listed id
  [ -n "$ISSUE" ] || return 0
  if ! git cat-file -e "$BASE^{commit}" 2> /dev/null; then
    ERRORS+=("The base commit $BASE is not in this checkout, so the PR's changes cannot be listed. Check out with full history (fetch-depth: 0).")
    return
  fi
  touched="$(git diff --name-only "$BASE"...HEAD |
    sed -nE "s#^openspec/changes/(archive/[0-9]{4}-[0-9]{2}-[0-9]{2}-)?(${ISSUE}-[0-9a-f]{6}-[^/]+)/.*#\2#p" | sort -u)"
  # shellcheck disable=SC2016 # literal markdown backticks
  listed="$(grep -oE '^Change: `[^`]+`' <<< "$BODY" | sed -E 's/^Change: `(.*)`$/\1/' | sort -u || true)"
  while IFS= read -r id; do
    [ -n "$id" ] && ERRORS+=("The PR changes $id but the body has no \"Change: \`$id\`\" line. Add one under ## Summary.")
  done < <(comm -23 <(printf '%s\n' "$touched") <(printf '%s\n' "$listed"))
  while IFS= read -r id; do
    [ -n "$id" ] && ERRORS+=("The body lists \"Change: \`$id\`\" but the PR does not change it. Remove the line.")
  done < <(comm -13 <(printf '%s\n' "$touched") <(printf '%s\n' "$listed"))
  return 0
}

check_test_plan() {
  if grep -iqE '^#{1,6}[[:space:]](.*[^a-z])?test[[:space:]]*plan' <<< "$BODY"; then
    ERRORS+=("Remove the test-plan section: CI is the test plan.")
  fi
}

check_heredoc() {
  local prose
  prose="$(awk '/^```/ { fenced = !fenced; next } !fenced' <<< "$BODY")" # code blocks may show heredocs
  # shellcheck disable=SC2016 # the literal text a heredoc paste leaves behind
  if grep -qE "^'?EOF'?$" <<< "$prose" || grep -qF '$(cat <<' <<< "$prose"; then
    ERRORS+=("The body was pasted from a shell heredoc (an EOF line or \$(cat <<). Write the body to a file and pass it with --body-file.")
  fi
}

check_home_paths() {
  local hit line path
  while IFS= read -r hit; do
    hit="${hit#<stdin>:}"
    line="${hit%%:*}"
    path="${hit#*: }"
    ERRORS+=("PR body line $line names $path, a path in one person's home directory. Name the file relative to the repository, or describe where it came from.")
  done < <(printf '%s\n' "$BODY" | "$HERE/check-home-paths.sh" - 2> /dev/null || true)
}

check_title
check_sections
check_issue_line
check_change_lines
check_test_plan
check_heredoc
check_home_paths

if [ "${#ERRORS[@]}" -gt 0 ]; then
  for error in "${ERRORS[@]}"; do
    echo "::error::$error" >&2
  done
  echo "Edit the PR's title or description to fix these; editing reruns this check." >&2
  exit 1
fi
echo "PR #$PR's title and body follow AGENTS.md → \"Pull requests\"."
