# shellcheck shell=bash disable=SC2154
# Baseline: bin/openspec-check-archived.sh

archived() { "$BIN/openspec-check-archived.sh" "$@"; }

# [spec-coverage-a47e0a]
test_non_change_branch_passes() {
  expect_pass archived 12-fix-typo
  expect_output "Not a change branch"
}

# [spec-coverage-5923b5]
test_unarchived_change_fails() {
  mkdir -p openspec/changes/1-a38e64-hooks
  expect_fail archived 1-a38e64-hooks
  expect_output "is not archived"
}

# [spec-coverage-0dc405]
test_missing_change_fails() {
  mkdir -p openspec/changes/archive
  expect_fail archived 1-a38e64-hooks
  expect_output "No change folder"
}

# [spec-coverage-0c30cb]
test_archived_change_passes() {
  mkdir -p openspec/changes/archive/2026-10-13-1-a38e64-hooks
  expect_pass archived 1-a38e64-hooks
  expect_output "is archived"
}

# [spec-coverage-73c973]
test_active_sibling_change_fails() {
  mkdir -p openspec/changes/archive/2026-10-24-234-3306ff-one openspec/changes/234-abcdef-two openspec/changes/234-123456-three
  expect_fail archived 234-3306ff-one
  expect_output "Change 234-abcdef-two is not archived"
  expect_output "Change 234-123456-three is not archived"
}

# [spec-coverage-73c973]
test_other_issues_changes_do_not_count() {
  mkdir -p openspec/changes/archive/2026-10-24-234-3306ff-one openspec/changes/23-abcdef-other openspec/changes/2345-abcdef-other
  expect_pass archived 234-3306ff-one
}

# [spec-coverage-73c973]
test_archived_siblings_pass() {
  mkdir -p openspec/changes/archive/2026-10-24-234-3306ff-one openspec/changes/archive/2026-10-24-234-abcdef-two
  expect_pass archived 234-3306ff-one
  expect_output "is archived"
}
