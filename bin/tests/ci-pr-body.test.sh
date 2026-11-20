# shellcheck shell=bash disable=SC2154,SC2016
# bin/ci-pr-body.sh against a fake gh that serves one PR, and a git history
# that holds the PR's diff.

setup_pr_body() {
  mkdir -p "$REPO/fakes"
  cat > "$REPO/fakes/gh" <<'GH'
#!/usr/bin/env bash
set -eu
[ "${GH_FAIL:-}" != 1 ] || { echo 'gh: HTTP 502' >&2; exit 1; }
case "$*" in
  "pr view 42 --json title,body,headRefName,baseRefOid")
    jq -n --arg title "$PR_TITLE" --arg body "$PR_BODY" --arg branch "$PR_BRANCH" --arg base "$PR_BASE" \
      '{title: $title, body: $body, headRefName: $branch, baseRefOid: $base}' ;;
  *) echo "fake gh: unexpected: $*" >&2; exit 2 ;;
esac
GH
  chmod +x "$REPO/fakes/gh"
  export PATH="$REPO/fakes:$PATH"
  # The PR's diff: from the base commit, the head adds the branch's change.
  PR_BASE="$(git rev-parse HEAD)"
  commit_change openspec/changes/12-a3f9c1-session-slots/tasks.md
  export PR_BASE PR_BRANCH=12-a3f9c1-session-slots PR_TITLE='[12][a3f9c1] Allocate session slots'
  PR_BODY="$(good_body 12 12-a3f9c1-session-slots)"
  export PR_BODY
}

# commit_change <path>...: commit a file at each path (the test repo has no hooks).
commit_change() {
  local path
  for path in "$@"; do
    mkdir -p "$(dirname "$path")"
    echo "# Tasks" > "$path"
  done
  git add -A
  git commit -q -m "[12] Change"
}

# good_body <issue> <change-id>...: a body that follows every rule.
good_body() {
  local issue="$1" id
  shift
  printf '## Summary\n\nWhy.\n\nCloses #%s\n' "$issue"
  for id in "$@"; do
    printf 'Change: `%s`\n' "$id"
  done
  printf '\n## Changes\n\n- What\n\n## Proof\n\nShown.\n'
}

# [ci-12ead1]
test_ci_12ead1_home_path_in_body_fails() {
  setup_pr_body
  PR_BODY="$(good_body 12 12-a3f9c1-session-slots)"$'\n![shot](/Users/alice/Desktop/screenshot.png)'
  expect_fail "$BIN/ci-pr-body.sh" 42
  expect_output '::error::'
  expect_output 'line 15'
  expect_output '/Users/alice'
}

test_edited_body_passes() {
  setup_pr_body
  PR_BODY="$(good_body 12 12-a3f9c1-session-slots)"$'\n![shot](proof/screenshot.png)'
  expect_pass "$BIN/ci-pr-body.sh" 42
}

test_pr_body_crlf_lines_still_count() {
  setup_pr_body
  PR_BODY="$(good_body 12 12-a3f9c1-session-slots | sed 's/$/\r/')"$'\n/home/bob/x\r'
  expect_fail "$BIN/ci-pr-body.sh" 42
  expect_output 'line 15'
}

test_pr_body_gh_failure_fails() {
  setup_pr_body
  export GH_FAIL=1
  expect_fail "$BIN/ci-pr-body.sh" 42
}

test_pr_body_usage() {
  local status=0
  "$BIN/ci-pr-body.sh" > /dev/null 2>&1 || status=$?
  [ "$status" -eq 2 ] || fail "no argument exited $status, expected 2"
  setup_pr_body
  export GH_FAIL=1 # gh must not be called
  status=0
  "$BIN/ci-pr-body.sh" not-a-number > /dev/null 2>&1 || status=$?
  [ "$status" -eq 2 ] || fail "a non-numeric PR exited $status, expected 2"
  expect_pass "$BIN/ci-pr-body.sh" --help
  expect_output 'usage: bin/ci-pr-body.sh <pr-number>'
  expect_output 'Closes #N'
}

# [ci-2ddea6]
test_ci_2ddea6_title_without_prefix_fails() {
  setup_pr_body
  PR_TITLE='Allocate session slots'
  expect_fail "$BIN/ci-pr-body.sh" 42
  expect_output 'must start with [12][a3f9c1]'
}

# [ci-ac8098]
test_ci_ac8098_long_title_with_prefix_passes() {
  setup_pr_body
  PR_TITLE="[12][a3f9c1] Allocate one isolated session slot per worktree so that many stacks run side by side on one laptop at once"
  [ "${#PR_TITLE}" -ge 113 ] || fail "the title is only ${#PR_TITLE} characters"
  expect_pass "$BIN/ci-pr-body.sh" 42
}

test_pr_title_other_branches_accept_any_prefix_form() {
  setup_pr_body
  PR_BRANCH=someone/438-dup PR_TITLE='[438] Renumber the duplicate scenario'
  PR_BODY="$(good_body 438)"
  expect_pass "$BIN/ci-pr-body.sh" 42
  PR_TITLE='[HOTFIX] Restore sign-in'
  expect_pass "$BIN/ci-pr-body.sh" 42
  PR_BRANCH=12-fix-typo PR_TITLE='[12][a3f9c1] Fix the typo'
  PR_BODY="$(good_body 12 12-a3f9c1-session-slots)"
  expect_fail "$BIN/ci-pr-body.sh" 42
  expect_output 'must start with [12]'
  PR_BRANCH=12-a3f9c1-session-slots PR_TITLE='[12][a3f9c1] lowercase start'
  expect_fail "$BIN/ci-pr-body.sh" 42
  expect_output 'capital letter'
  PR_TITLE='[12][a3f9c1] ui: Fix the typo'
  expect_pass "$BIN/ci-pr-body.sh" 42
}

# [ci-3c3413]
test_ci_3c3413_missing_proof_and_closes_fail_together() {
  setup_pr_body
  PR_BODY=$'## Summary\n\nWhy.\n\nChange: `12-a3f9c1-session-slots`\n\n## Changes\n\n- What'
  expect_fail "$BIN/ci-pr-body.sh" 42
  expect_output '## Proof'
  expect_output 'Closes #12'
}

# [ci-7e21a7]
test_ci_7e21a7_test_plan_section_fails() {
  setup_pr_body
  PR_BODY="$(good_body 12 12-a3f9c1-session-slots)"$'\n\n### Test Plan\n\n- [ ] Run it'
  expect_fail "$BIN/ci-pr-body.sh" 42
  expect_output 'test-plan section'
}

# [ci-d22c12]
test_ci_d22c12_heredoc_leftovers_fail() {
  setup_pr_body
  PR_BODY="$(good_body 12 12-a3f9c1-session-slots)"$'\nEOF'
  expect_fail "$BIN/ci-pr-body.sh" 42
  expect_output 'heredoc'
  PR_BODY="\$(cat <<'EOF'"$'\n'"$(good_body 12 12-a3f9c1-session-slots)"
  expect_fail "$BIN/ci-pr-body.sh" 42
  expect_output 'heredoc'
}

# [ci-cbbebe]
test_ci_cbbebe_extra_sections_and_commands_pass() {
  setup_pr_body
  PR_BODY=$'## Summary\n\nWhy.\n\nCloses #12\nChange: `12-a3f9c1-session-slots`\n\n## Changes\n\n- What\n\n## Parked for the designer\n\n- A question\n\n## Proof\n\n```\n$ bin/tests/run.sh hooks\n16 passed, 0 failed\n```'
  expect_pass "$BIN/ci-pr-body.sh" 42
}

# [ci-6b0a4e]
test_ci_6b0a4e_hotfix_needs_no_issue_line() {
  setup_pr_body
  PR_BRANCH=hotfix-sign-in PR_TITLE='[HOTFIX] Restore sign-in'
  PR_BODY=$'## Summary\n\nWhy.\n\n## Changes\n\n- What\n\n## Proof\n\nShown.'
  expect_pass "$BIN/ci-pr-body.sh" 42
}

# [ci-5c19b5]
test_ci_5c19b5_pr_body_closes_must_name_the_exact_issue() {
  setup_pr_body
  PR_BODY="$(good_body 123 12-a3f9c1-session-slots)"
  expect_fail "$BIN/ci-pr-body.sh" 42
  expect_output 'Closes #12'
}

test_pr_body_headings_tolerate_crlf_and_trailing_spaces() {
  setup_pr_body
  PR_BODY="$(good_body 12 12-a3f9c1-session-slots | sed 's/^## Proof$/## Proof  /; s/$/\r/')"
  expect_pass "$BIN/ci-pr-body.sh" 42
}

# [ci-c9f2b8]
test_ci_c9f2b8_pr_body_sections_out_of_order_fail() {
  setup_pr_body
  PR_BODY=$'## Summary\n\nCloses #12\nChange: `12-a3f9c1-session-slots`\n\n## Proof\n\nShown.\n\n## Changes\n\n- What'
  expect_fail "$BIN/ci-pr-body.sh" 42
  expect_output 'in that order'
}

# [ci-15a4f9]
test_ci_15a4f9_missing_change_line_fails() {
  setup_pr_body
  commit_change openspec/changes/12-b4e0d2-slot-reaping/tasks.md
  expect_fail "$BIN/ci-pr-body.sh" 42
  expect_output '12-b4e0d2-slot-reaping'
}

# [ci-257c8c]
test_ci_257c8c_archived_change_counts() {
  setup_pr_body
  PR_BASE="$(git rev-parse HEAD)"
  mkdir -p openspec/changes/archive
  git mv openspec/changes/12-a3f9c1-session-slots openspec/changes/archive/2026-11-06-12-a3f9c1-session-slots
  git commit -q -m "[12][a3f9c1] Archive 12-a3f9c1-session-slots"
  expect_pass "$BIN/ci-pr-body.sh" 42
}

# [ci-dff6f4]
test_ci_dff6f4_line_for_untouched_change_fails() {
  setup_pr_body
  PR_BODY="$(good_body 12 12-a3f9c1-session-slots 12-c9d8e7-other)"
  expect_fail "$BIN/ci-pr-body.sh" 42
  expect_output '12-c9d8e7-other'
}

test_pr_body_other_issues_changes_need_no_line() {
  setup_pr_body
  commit_change openspec/changes/99-aaaaaa-merged-from-main/x.md
  expect_pass "$BIN/ci-pr-body.sh" 42
}

test_pr_body_missing_base_fails_loudly() {
  setup_pr_body
  PR_BASE=0123456789abcdef0123456789abcdef01234567
  expect_fail "$BIN/ci-pr-body.sh" 42
  expect_output 'full history'
}

test_pr_body_plan_headings_that_are_not_test_plans_pass() {
  setup_pr_body
  PR_BODY="$(good_body 12 12-a3f9c1-session-slots)"$'\n\n### Latest plan\n\n### Contest planner'
  expect_pass "$BIN/ci-pr-body.sh" 42
}

# [ci-d22c12]
test_ci_d22c12_pr_body_heredoc_inside_a_code_block_passes() {
  setup_pr_body
  PR_BODY="$(good_body 12 12-a3f9c1-session-slots)"$'\n\n```bash\ncat > x <<\'EOF\'\nhello\nEOF\n```'
  expect_pass "$BIN/ci-pr-body.sh" 42
}
