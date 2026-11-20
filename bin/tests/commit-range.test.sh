# shellcheck shell=bash disable=SC2154
# bin/check-commit-range.sh

commit() { git commit -q --allow-empty -m "$1"; }
range() { "$BIN/check-commit-range.sh" 1-a38e64-git-hooks "$@"; }

# [repo-rules-78f6f8] [repo-rules-9cdb65]
test_one_bad_commit_fails_the_range() {
  local base
  base="$(git rev-parse HEAD)"
  commit "[1][a38e64] Add one"
  commit "add two"
  commit "[1][a38e64] Add three"
  expect_fail range "$base" HEAD
  expect_output "$(git rev-parse --short HEAD~1): Bad commit subject: add two"
  expect_output "1 of 3 commit subjects are malformed"
  expect_output "ask a human"
  [[ "$OUT" != *force-push* && "$OUT" != *--force* ]] || fail "the advice names a force-push: $OUT"
  [[ "$OUT" != *"Add one"* ]] || fail "a good commit was reported"
}

# [repo-rules-78f6f8]
test_every_bad_commit_is_reported() {
  local base
  base="$(git rev-parse HEAD)"
  commit "add one"
  commit "add two"
  expect_fail range "$base" HEAD
  expect_output "add one"
  expect_output "add two"
}

# [repo-rules-43b88d] [repo-rules-4a1a86]
test_merge_commits_are_skipped() {
  local base
  base="$(git rev-parse HEAD)"
  git checkout -q -b side
  commit "[1][a38e64] Add side"
  git checkout -q main
  commit "[1][a38e64] Add main"
  git merge -q --no-ff -m "Merge branch 'side'" side
  expect_pass range "$base" HEAD
  # The side commit came in through the merge's second parent.
  expect_output "Checked 1 commit subjects."
}

# [repo-rules-777ce1]
test_range_rejects_fixup_commits() {
  local base
  base="$(git rev-parse HEAD)"
  commit "[1][a38e64] Add hooks"
  commit "fixup! [1][a38e64] Add hooks"
  expect_fail range "$base" HEAD
  expect_output "fixup! [1][a38e64] Add hooks"
}

test_empty_range_passes() {
  expect_pass range HEAD HEAD
  expect_output "Checked 0 commit subjects."
}

test_unknown_base_fails() {
  expect_fail range 0123456789abcdef0123456789abcdef01234567 HEAD
  expect_output "fatal:"
}

# [repo-rules-4a1a86]
test_merged_in_history_is_not_checked() {
  local base
  base="$(git rev-parse HEAD)"
  git checkout -q --orphan side
  git rm -rq --cached . 2>/dev/null || true
  commit "add one"
  commit "wip"
  git checkout -q main
  commit "[1][a38e64] Add main"
  git merge -q --allow-unrelated-histories --no-ff -m "[1][a38e64] Import side" side
  expect_pass range "$base" HEAD
  expect_output "Checked 1 commit subjects."
}

test_first_parent_still_checks_branch_commits_after_merging_main() {
  local base
  base="$(git rev-parse HEAD)"
  git checkout -q -b feature
  commit "bad subject"
  git checkout -q main
  commit "[1][a38e64] Add main"
  git checkout -q feature
  git merge -q --no-ff -m "Merge branch 'main'" main
  expect_fail range "$base" HEAD
  expect_output "bad subject"
  expect_output "1 of 1 commit subjects are malformed"
}
