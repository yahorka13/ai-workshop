# shellcheck shell=bash disable=SC2154
# bin/ci-change-archived.sh, with a fake `gh` that
# reports the pull request's live draft state from $FAKE_IS_DRAFT.

ci_archived() { "$BIN/ci-change-archived.sh" "$@"; }

fake_gh() {
  mkdir -p fake-bin
  cat > fake-bin/gh <<'GH'
#!/usr/bin/env bash
[ "$*" = "pr view 10 --json isDraft --jq .isDraft" ] || { echo "unexpected: gh $*" >&2; exit 1; }
[ -n "${FAKE_IS_DRAFT:-}" ] || { echo "gh: HTTP 502" >&2; exit 1; }
echo "$FAKE_IS_DRAFT"
GH
  chmod +x fake-bin/gh
  PATH="$PWD/fake-bin:$PATH"
}

# [ci-10858b]
test_ready_pr_with_unarchived_change_fails() {
  fake_gh
  mkdir -p openspec/changes/1-a38e64-hooks
  FAKE_IS_DRAFT=false expect_fail ci_archived 10 1-a38e64-hooks
  expect_output "is not archived"
}

# [ci-10858b]
test_ready_pr_with_archived_change_passes() {
  fake_gh
  mkdir -p openspec/changes/archive/2026-10-13-1-a38e64-hooks
  FAKE_IS_DRAFT=false expect_pass ci_archived 10 1-a38e64-hooks
  expect_output "is archived"
}

# [ci-9d2e23]
test_draft_pr_passes_without_checking() {
  fake_gh
  mkdir -p openspec/changes/1-a38e64-hooks
  FAKE_IS_DRAFT=true expect_pass ci_archived 10 1-a38e64-hooks
  expect_output "PR #10 is a draft"
}

# [ci-4d6562]
test_unknown_draft_state_fails_closed() {
  fake_gh
  mkdir -p openspec/changes/archive/2026-10-13-1-a38e64-hooks
  FAKE_IS_DRAFT="" expect_fail ci_archived 10 1-a38e64-hooks
  expect_output "HTTP 502"
}

test_ci_change_archived_rejects_wrong_arguments() {
  expect_fail ci_archived 10
  expect_output "usage:"
}
