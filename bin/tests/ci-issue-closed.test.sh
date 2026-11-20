# shellcheck shell=bash disable=SC2154,SC2016 # literal workflow expressions
# bin/ci-issue-closed.sh, with a fake `gh`
# that reports the issue's labels from $FAKE_LABELS (newline-separated) and
# logs every call to gh.log, one line per call with each argument in brackets.

issue_closed() { "$BIN/ci-issue-closed.sh" "$@"; }

fake_gh() {
  mkdir -p fake-bin
  cat > fake-bin/gh <<'GH'
#!/usr/bin/env bash
{ printf '[%s]' "$@"; echo; } >> gh.log
case "$*" in
  "issue view 7 --json labels --jq .labels[].name") printf '%s\n' "$FAKE_LABELS" ;;
  "issue edit 7 --remove-label in progress") ;;
  *) echo "unexpected: gh $*" >&2; exit 1 ;;
esac
GH
  chmod +x fake-bin/gh
  PATH="$PWD/fake-bin:$PATH"
  : > gh.log
}

# [agent-workflow-1f6fa7]
test_closed_issue_loses_label() {
  fake_gh
  FAKE_LABELS=$'bug\nin progress' expect_pass issue_closed 7
  grep -qF '[issue][edit][7][--remove-label][in progress]' gh.log || fail "label not removed"$'\n'"$(cat gh.log)"
}

# [agent-workflow-bfbf53]
test_closed_issue_without_label_passes() {
  fake_gh
  FAKE_LABELS=bug expect_pass issue_closed 7
  ! grep -q '^\[issue\]\[edit\]' gh.log || fail "expected no edit"$'\n'"$(cat gh.log)"
}

test_ci_issue_closed_rejects_wrong_arguments() {
  expect_fail issue_closed
  expect_output "usage:"
}

# the issue-closed job holds issues: write and passes
# bin/ci-issue-closed.sh only the workflow's own token.
# [agent-workflow-c6112b]
test_issue_closed_job_holds_only_issues_write() {
  local workflow="$ROOT/.github/workflows/issues.yml" job
  grep -qxF 'permissions: {}' "$workflow" || fail 'issues.yml grants permissions workflow-wide'
  job="$(awk '/^  issue-closed:$/ { on = 1; next } /^  [a-z]/ { on = 0 } on' "$workflow")"
  [ -n "$job" ] || fail 'issues.yml has no issue-closed job'
  [ "$(awk '/^    permissions:$/ { on = 1; next } /^    [a-z]/ { on = 0 } on' <<< "$job")" = $'      contents: read\n      issues: write' ] \
    || fail "the issue-closed job holds other permissions: $job"
  grep -qF 'run: bin/ci-issue-closed.sh "$ISSUE"' <<< "$job" || fail 'the job does not run bin/ci-issue-closed.sh'
  grep -qxF '          GH_TOKEN: ${{ github.token }}' <<< "$job" || fail 'the job does not pass github.token'
  [ "$(grep -cE 'secrets\.|TOKEN' <<< "$job")" = 1 ] || fail "the job passes a credential besides github.token: $job"
}
