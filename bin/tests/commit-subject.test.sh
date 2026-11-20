# shellcheck shell=bash disable=SC2154
# bin/check-commit-subject.sh and bin/commit-prefix.sh

subject() { "$BIN/check-commit-subject.sh" "$@"; }

test_commit_prefix_follows_the_branch() {
  [ "$("$BIN/commit-prefix.sh" 1-a38e64-git-hooks)" = "[1][a38e64]" ] || fail "change branch"
  [ "$("$BIN/commit-prefix.sh" 12-fix-typo)" = "[12]" ] || fail "issue branch"
  [ -z "$("$BIN/commit-prefix.sh" hotfix-login)" ] || fail "other branch"
}

# [repo-rules-c8d469]
test_change_branch_accepts_its_issue_and_hash() {
  expect_pass subject 1-a38e64-git-hooks "[1][a38e64] Add hooks"
}

# [repo-rules-8e90f9]
test_change_branch_rejects_wrong_or_missing_hash() {
  expect_fail subject 1-a38e64-git-hooks "[1] Add hooks"
  expect_output 'expected subject to start with "[1][a38e64] "'
  expect_fail subject 1-a38e64-git-hooks "[1][bbbbbb] Add hooks"
  expect_output 'expected subject to start with "[1][a38e64] "'
}

# [repo-rules-b32b92]
test_issue_branch_requires_its_issue_number() {
  expect_fail subject 12-fix-typo "[13] Fix typo"
  expect_output 'expected subject to start with "[12] "'
  expect_pass subject 12-fix-typo "[12] Fix typo"
}

# [repo-rules-2f8e68]
test_other_branches_accept_any_valid_prefix() {
  expect_pass subject hotfix-login "[HOTFIX] Fix login"
  expect_pass subject hotfix-login "[7] Fix login"
  expect_pass subject hotfix-login "[7][a1b2c3] Fix login"
  expect_pass subject HEAD "[7] Fix login"
}

# [repo-rules-6d5b27]
test_unprefixed_subject_is_rejected() {
  expect_fail subject hotfix-login "Fix login"
  expect_output "Bad commit subject: Fix login"
  expect_fail subject hotfix-login "12: Fix login"
  expect_fail subject hotfix-login "[HOTFIX]Fix login"
  expect_fail subject hotfix-login "[7][abc] Fix login"
}

# [repo-rules-3adb07]
test_scoped_sentence_case_subject_passes() {
  expect_pass subject 12-a3f9c1-tokens "[12][a3f9c1] api: Reject expired tokens"
}

# [repo-rules-0f67af]
test_lowercase_description_is_rejected() {
  expect_fail subject 12-tokens "[12] add tokens"
  expect_output "uppercase"
  expect_fail subject 12-tokens "[12] api: reject tokens"
  expect_fail subject 12-tokens "[12] "
}

# [repo-rules-5c481b]
test_overlong_subject_is_rejected() {
  local s72
  s72="[12] A$(printf '%066d' 0 | tr 0 x)"
  [ "${#s72}" -eq 72 ] || fail "fixture is ${#s72} characters"
  expect_pass subject 12-tokens "$s72"
  expect_fail subject 12-tokens "${s72}x"
  expect_output "73 characters; the limit is 72"
}

# [repo-rules-777ce1]
test_subject_check_rejects_fixups() {
  expect_fail subject 1-a38e64-git-hooks "fixup! [1][a38e64] Add hooks"
  expect_output "squashed before merge"
  expect_fail subject 1-a38e64-git-hooks "squash! [1][a38e64] Add hooks"
}

# [repo-rules-7c7601]
test_subject_check_allows_fixups_when_asked() {
  expect_pass subject --allow-fixup 1-a38e64-git-hooks "fixup! [1][a38e64] Add hooks"
}

test_subject_check_rejects_wrong_arguments() {
  expect_fail subject only-one-argument
  expect_output "usage:"
}

# [repo-rules-777ce1]
test_subject_check_rejects_amend_fixups() {
  expect_fail subject 1-a38e64-git-hooks "amend! [1][a38e64] Add hooks"
  expect_output "squashed before merge"
  expect_pass subject --allow-fixup 1-a38e64-git-hooks "amend! [1][a38e64] Add hooks"
}

# [repo-rules-b507a6]
test_a_merged_sibling_change_keeps_its_own_hash() {
  mkdir -p openspec/changes/12-d7b3e6-slot-reaper
  mkdir -p openspec/changes/archive/2026-10-15-12-a51829-slot-registry
  # The branch's own hash, an active sibling and an archived sibling all pass.
  expect_pass subject 12-fbbdc6-session-slots "[12][fbbdc6] Add the slots"
  expect_pass subject 12-fbbdc6-session-slots "[12][d7b3e6] Reap stale slots"
  expect_pass subject 12-fbbdc6-session-slots "[12][a51829] Add the registry"
}

# [repo-rules-b507a6]
test_an_unknown_or_foreign_hash_is_rejected() {
  mkdir -p openspec/changes/archive/2026-10-15-12-a51829-slot-registry
  mkdir -p openspec/changes/7-b0b0b0-something-else
  # A hash no change of this issue has, and a hash from another issue.
  expect_fail subject 12-fbbdc6-session-slots "[12][ffffff] Invented hash"
  expect_output "another change of that issue"
  expect_fail subject 12-fbbdc6-session-slots "[7][b0b0b0] Another issue's change"
}
