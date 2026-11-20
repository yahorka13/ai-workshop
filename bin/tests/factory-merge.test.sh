# shellcheck shell=bash disable=SC2154
# bin/factory-merge, with a fake `gh` that answers `pr view` from $FAKE_PR
# ("<state> <isDraft> <mergeable>") with head commit $FAKE_HEAD and base main,
# the comparison of main with that head from $FAKE_BEHIND (commits of main the
# head lacks), `pr checks` from $FAKE_CHECKS (lines
# "<bucket> <name>"; unset prints gh's "no checks reported" and exits 1, and a
# failing or pending check makes it exit 1 or 8 as gh does), and logs every
# call to gh.log, one line per call with each argument in brackets.

merge_pr() { "$BIN/factory-merge" "$@"; }

merge_fixture() {
  mkdir -p fake-bin
  cat > fake-bin/gh <<'GH'
#!/usr/bin/env bash
{ printf '[%s]' "$@"; echo; } >> gh.log
case "$1 $2" in
  "pr view") [ -z "${FAKE_VIEW_EXIT:-}" ] || { echo "To get started with GitHub CLI, please run:  gh auth login" >&2; exit "$FAKE_VIEW_EXIT"; }; set -- $FAKE_PR; printf '%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$FAKE_HEAD" main ;;
  "api repos/o/r/compare/main...$FAKE_HEAD") echo "$FAKE_BEHIND" ;;
  "pr checks")
    if [ -z "${FAKE_CHECKS+set}" ]; then echo "no checks reported on the 'x' branch" >&2; exit 1; fi
    printf '%s\n' "$FAKE_CHECKS" | while read -r bucket name; do [ -z "$bucket" ] || printf '%s\t%s\n' "$bucket" "$name"; done
    case "$FAKE_CHECKS" in *fail*|*cancel*) exit 1 ;; *pending*) exit 8 ;; esac ;;
  "pr merge") ;;
  *) echo "unexpected: gh $*" >&2; exit 1 ;;
esac
GH
  chmod +x fake-bin/gh
  PATH="$PWD/fake-bin:$PATH"
  : > gh.log
  git remote add origin git@github.com:o/r.git
  export FAKE_HEAD=c0ffee FAKE_BEHIND=0 FAKE_PR='OPEN false MERGEABLE' FAKE_CHECKS=$'pass checks\nskipping mutation'
}

# expect_refused <reason>: the last run exited 3, named the reason and merged nothing.
expect_refused() {
  local status=0
  OUT="$(merge_pr 7 2>&1)" || status=$?
  [ "$status" = 3 ] || fail "expected exit 3, got $status"$'\n'"$OUT"
  expect_output "not merged: $1"
  ! grep -qF '[pr][merge]' gh.log || fail "merged anyway"$'\n'"$(cat gh.log)"
}

# [agent-workflow-792ec5] [agent-workflow-1ebd00]
test_green_ready_pr_is_merged() {
  merge_fixture
  expect_pass merge_pr 7
  grep -qF '[pr][merge][7][-R][o/r][--merge][--delete-branch][--match-head-commit][c0ffee]' gh.log || fail "not merged as expected"$'\n'"$(cat gh.log)"
  expect_output "merged #7"
}

# [agent-workflow-03d810]
test_failed_check_blocks_merge() {
  merge_fixture
  FAKE_CHECKS=$'pass checks\nfail e2e' expect_refused 'check failed: e2e'
}

# [agent-workflow-bbad9e]
test_draft_pr_is_not_merged() {
  merge_fixture
  FAKE_PR='OPEN true MERGEABLE' expect_refused draft
}

# [agent-workflow-bbad9e]
test_conflicting_pr_is_not_merged() {
  merge_fixture
  FAKE_PR='OPEN false CONFLICTING' expect_refused conflicting
}

# [agent-workflow-bbad9e]
test_pending_check_is_not_merged() {
  merge_fixture
  FAKE_CHECKS=$'pass checks\npending e2e' expect_refused 'checks pending'
}

test_closed_pr_is_not_merged() {
  merge_fixture
  FAKE_PR='MERGED false UNKNOWN' expect_refused 'not open'
}

test_unknown_mergeable_is_pending() {
  merge_fixture
  FAKE_PR='OPEN false UNKNOWN' expect_refused 'checks pending'
}

test_pr_without_checks_is_pending() {
  merge_fixture
  unset FAKE_CHECKS
  expect_refused 'checks pending'
}

test_cancelled_check_blocks_merge() {
  merge_fixture
  FAKE_CHECKS=$'pass checks\ncancel e2e' expect_refused 'check failed: e2e'
}

test_usage_errors() {
  merge_fixture
  local args status
  for args in '' abc '7 8'; do
    status=0
    # shellcheck disable=SC2086 # split the argument list on purpose
    OUT="$(merge_pr $args 2>&1)" || status=$?
    [ "$status" = 2 ] || fail "expected exit 2 for '$args', got $status"
    expect_output 'usage: bin/factory-merge'
  done
  [ ! -s gh.log ] || fail "a usage error called gh"
  PATH=/usr/bin:/bin expect_pass merge_pr --help
}

# A PR that cannot be read is a failure, not a verdict: no "not merged" reason,
# no exit 3, and no merge.
test_unreadable_pr_fails_without_a_verdict() {
  merge_fixture
  local status=0
  OUT="$(FAKE_VIEW_EXIT=4 merge_pr 7 2>&1)" || status=$?
  [ "$status" != 0 ] && [ "$status" != 3 ] || fail "an unreadable PR exited $status"$'\n'"$OUT"
  [[ "$OUT" != *"not merged:"* ]] || fail "an unreadable PR got a verdict"$'\n'"$OUT"
  ! grep -qF '[pr][merge]' gh.log || fail "merged anyway"
}

# [agent-workflow-60965a]
test_pr_behind_main_is_not_merged() {
  merge_fixture
  FAKE_BEHIND=2 expect_refused 'behind main'
}
