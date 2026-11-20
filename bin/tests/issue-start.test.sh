# shellcheck shell=bash disable=SC2154
# bin/issue-start,
# with a fake `gh` that answers from $FAKE_ME, $FAKE_AUTHOR, $FAKE_ASSIGNEES
# (space-separated), $FAKE_LABELS and $FAKE_REPO_LABELS (newline-separated),
# fails to read the issue when $FAKE_VIEW_FAILS is set, fails to create the
# label when $FAKE_CREATE_FAILS is set, or because another claim created it
# meanwhile when $FAKE_CREATE_RACES is set, and logs every call to
# gh.log, one line per call with each argument in brackets.

issue_start() { "$BIN/issue-start" "$@"; }

fake_gh() {
  mkdir -p fake-bin
  cat > fake-bin/gh <<'GH'
#!/usr/bin/env bash
{ printf '[%s]' "$@"; echo; } >> gh.log
case "$1 $2" in
  "api user") echo "$FAKE_ME" ;;
  "issue view")
    [ -z "${FAKE_VIEW_FAILS:-}" ] || { echo "GraphQL: Could not resolve to an issue with the number of $3." >&2; exit 1; }
    case "$*" in
      *.author.login*) echo "$FAKE_AUTHOR" ;;
      *.assignees*) for a in ${FAKE_ASSIGNEES:-}; do echo "$a"; done ;;
      *.labels*) [ -z "${FAKE_LABELS:-}" ] || printf '%s\n' "$FAKE_LABELS" ;;
      *) echo "unexpected: gh $*" >&2; exit 1 ;;
    esac ;;
  "label list")
    [ ! -f raced ] || echo "in progress"
    [ -z "${FAKE_REPO_LABELS:-}" ] || printf '%s\n' "$FAKE_REPO_LABELS" ;;
  "label create")
    [ -z "${FAKE_CREATE_FAILS:-}" ] || { echo "HTTP 403: Resource not accessible by integration" >&2; exit 1; }
    [ -z "${FAKE_CREATE_RACES:-}" ] || { touch raced; echo "label with name \"$3\" already exists; use \`--force\` to update its color and description" >&2; exit 1; } ;;
  "issue edit") ;;
  *) echo "unexpected: gh $*" >&2; exit 1 ;;
esac
GH
  chmod +x fake-bin/gh
  PATH="$PWD/fake-bin:$PATH"
  : > gh.log
  git remote add origin git@github.com:o/r.git 2> /dev/null || true
  export FAKE_ME=me FAKE_AUTHOR=alice FAKE_ASSIGNEES='' FAKE_LABELS='' FAKE_REPO_LABELS=$'bug\nin progress'
}

# expect_logged <arg>... fails unless one gh call held these arguments, in
# order and next to each other.
expect_logged() {
  grep -qF -- "$(printf '[%s]' "$@")" gh.log || fail "gh was not called with: $*"$'\n'"$(cat gh.log)"
}

no_edit() {
  ! grep -q '^\[issue\]\[edit\]' gh.log || fail "expected no issue edit"$'\n'"$(cat gh.log)"
}

# [agent-workflow-57ec06]
test_free_issue_is_claimed() {
  fake_gh
  expect_pass issue_start 12
  expect_output "Started by @me"
  expect_logged issue edit 12 -R o/r --add-assignee me --add-label 'in progress'
  ! grep -qF -- '[--remove-assignee]' gh.log || fail "nothing to remove from an unassigned issue"
}

# [agent-workflow-57ec06]
test_issue_assigned_to_its_author_is_claimed() {
  fake_gh
  FAKE_ASSIGNEES=alice expect_pass issue_start 12
  expect_output "Started by @me"
  expect_logged issue edit 12 -R o/r --remove-assignee alice --add-assignee me --add-label 'in progress'
}

# [agent-workflow-0928ea]
test_missing_label_is_created() {
  fake_gh
  FAKE_REPO_LABELS=bug expect_pass issue_start 12
  expect_logged label create 'in progress' -R o/r
  [ "$(grep -n '^\[label\]\[create\]' gh.log | cut -d: -f1)" -lt "$(grep -n '^\[issue\]\[edit\]' gh.log | cut -d: -f1)" ] ||
    fail "the label must exist before the issue is labelled"$'\n'"$(cat gh.log)"
}

# [agent-workflow-0928ea]
test_existing_label_is_not_created_again() {
  fake_gh
  expect_pass issue_start 12
  ! grep -q '^\[label\]\[create\]' gh.log || fail "the label already exists"$'\n'"$(cat gh.log)"
}

# [agent-workflow-fa3504]
test_resume_changes_nothing() {
  fake_gh
  FAKE_ASSIGNEES=me FAKE_LABELS=$'bug\nin progress' expect_pass issue_start 12
  expect_output "Started by @me"
  no_edit
}

# [agent-workflow-f43ecb]
test_in_progress_elsewhere_is_refused() {
  fake_gh
  OUT="$(FAKE_ASSIGNEES=bob FAKE_LABELS='in progress' issue_start 12 2>&1)" && fail "expected exit 3"$'\n'"$OUT" || status=$?
  [ "$status" = 3 ] || fail "expected exit 3, got $status"$'\n'"$OUT"
  expect_output "@bob"
  expect_output "--take-over"
  no_edit
}

# [agent-workflow-f43ecb]
test_in_progress_author_elsewhere_is_refused() {
  fake_gh
  OUT="$(FAKE_ASSIGNEES=alice FAKE_LABELS='in progress' issue_start 12 2>&1)" || status=$?
  [ "${status:-0}" = 3 ] || fail "expected exit 3, got ${status:-0}"$'\n'"$OUT"
  expect_output "@alice"
  no_edit
}

# [agent-workflow-b22bf2]
test_third_person_is_refused() {
  fake_gh
  OUT="$(FAKE_ASSIGNEES=bob issue_start 12 2>&1)" || status=$?
  [ "${status:-0}" = 3 ] || fail "expected exit 3, got ${status:-0}"$'\n'"$OUT"
  expect_output "@bob"
  no_edit
}

# [agent-workflow-b22bf2]
test_bot_author_counts_as_author() {
  fake_gh
  FAKE_AUTHOR=app/renovate FAKE_ASSIGNEES=app/renovate expect_pass issue_start 12
  expect_logged --remove-assignee app/renovate --add-assignee me
}

# [agent-workflow-dbe4d3]
test_take_over_replaces_holders() {
  fake_gh
  FAKE_ASSIGNEES='bob carol' FAKE_LABELS='in progress' expect_pass issue_start 12 --take-over
  expect_output "Started by @me"
  expect_logged issue edit 12 -R o/r --remove-assignee bob,carol --add-assignee me --add-label 'in progress'
}

test_issue_start_fails_when_gh_cannot_read_the_issue() {
  fake_gh
  OUT="$(FAKE_VIEW_FAILS=1 issue_start 999 2>&1)" && fail "expected failure" || status=$?
  [ "$status" != 3 ] || fail "a read error must not look like a taken issue"
  expect_output "Could not resolve to an issue"
  no_edit
}

test_issue_start_rejects_wrong_arguments() {
  fake_gh
  local args
  for args in "" "abc" "12 --force" "12 --take-over extra"; do
    # shellcheck disable=SC2086 # split the argument list on purpose
    OUT="$(issue_start $args 2>&1)" && fail "expected usage error: $args" || status=$?
    [ "$status" = 2 ] || fail "expected exit 2 for '$args', got $status"
    expect_output "usage:"
  done
  no_edit
}

test_issue_start_prints_help() {
  expect_pass issue_start --help
  expect_output "--take-over"
}

test_issue_start_names_the_repository_from_origin() {
  fake_gh
  git remote set-url origin https://github.com/someone/their-crm.git
  expect_pass issue_start 12
  expect_logged issue edit 12 -R someone/their-crm --add-assignee me --add-label 'in progress'
}

test_issue_start_without_origin_fails_with_fix() {
  fake_gh
  git remote remove origin
  expect_fail issue_start 12
  expect_output 'git remote add origin'
  no_edit
}

# [agent-workflow-da1b1f]
test_label_created_meanwhile_is_used() {
  fake_gh
  export FAKE_REPO_LABELS=bug FAKE_CREATE_RACES=1
  expect_pass issue_start 7
  expect_output "Started by @me"
  expect_logged issue edit 7 -R o/r --add-assignee me --add-label "in progress"
}

test_label_creation_failure_fails_the_claim() {
  fake_gh
  export FAKE_REPO_LABELS=bug FAKE_CREATE_FAILS=1
  expect_fail issue_start 7
  expect_output "HTTP 403"
  no_edit
}
