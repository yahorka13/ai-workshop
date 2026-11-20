# shellcheck shell=bash disable=SC2154
# bin/check-lint-disables.sh: each service's eslint-disable and
# @ts-expect-error comments against the committed bin/lint-disables.txt, and
# no tracked eslint-suppressions.json under services/.

# Commits the baseline <lines> and each <path> with one suppression.
disables_commit() {
  local baseline="$1" path
  shift
  mkdir -p bin
  printf '%s\n' "$baseline" > bin/lint-disables.txt
  for path in "$@"; do
    mkdir -p "$(dirname "$path")"
    printf '%s\n' "// eslint-disable-next-line x -- y" "export const a = 1;" > "$path"
  done
  git add -A
  git commit -q -m "[1] Add suppressions"
}

# [repo-rules-64c670]
test_a_new_suppression_fails() {
  disables_commit "api 0" services/api/src/a.ts
  expect_fail "$BIN/check-lint-disables.sh" "$REPO"
  expect_output "api: 1 > 0"
  expect_output "services/api/src/a.ts:1"
  printf 'api 1\n' > bin/lint-disables.txt
  git commit -q -am "[1] Raise the baseline"
  expect_pass "$BIN/check-lint-disables.sh" "$REPO"
}

# [repo-rules-64c670]
test_ts_expect_error_and_each_comment_count() {
  disables_commit "api 1" services/api/src/a.ts
  mkdir -p services/api/tests
  printf '%s\n' "// @ts-expect-error -- y" "// eslint-disable-line x -- y /* eslint-disable-line z -- w */" > services/api/tests/b.test.ts
  git add -A
  git commit -q -m "[1] Add more"
  expect_fail "$BIN/check-lint-disables.sh" "$REPO"
  expect_output "api: 4 > 1"
  expect_output "services/api/tests/b.test.ts:1"
  expect_output "services/api/tests/b.test.ts:2"
}

# [repo-rules-c50a83]
test_a_removed_suppression_lowers_the_baseline() {
  disables_commit "api 2" services/api/src/a.ts
  expect_fail "$BIN/check-lint-disables.sh" "$REPO"
  expect_output "api: 1 < 2, commit bin/lint-disables.txt with api 1"
  printf 'api 1\n' > bin/lint-disables.txt
  git commit -q -am "[1] Lower the baseline"
  expect_pass "$BIN/check-lint-disables.sh" "$REPO"
}

# [repo-rules-fb5bf1]
test_generated_code_is_not_counted() {
  disables_commit $'api 0\nui 0' \
    services/api/src/generated/g.ts \
    services/api/contracts/c.ts \
    services/ui/src/services/graphql/generated/gql.ts
  printf '%s\n' "// eslint-disable-next-line x -- y" > services/api/README.md
  git add -A
  git commit -q -m "[1] Add docs"
  expect_pass "$BIN/check-lint-disables.sh" "$REPO"
}

test_untracked_files_are_not_counted() {
  disables_commit "api 0"
  mkdir -p services/api/src
  printf '%s\n' "// eslint-disable-next-line x -- y" > services/api/src/new.ts
  expect_pass "$BIN/check-lint-disables.sh" "$REPO"
}

test_missing_service_line_fails() {
  disables_commit "api 0" services/web/src/a.ts
  expect_fail "$BIN/check-lint-disables.sh" "$REPO"
  expect_output "web: no line in bin/lint-disables.txt, add web 1"
}

test_check_lint_disables_usage() {
  expect_pass "$BIN/check-lint-disables.sh" --help
  expect_output "Usage: bin/check-lint-disables.sh"
  expect_fail "$BIN/check-lint-disables.sh" "$REPO" extra
  expect_output "Usage:"
}

# [repo-rules-d4605b]
test_a_tracked_suppressions_file_fails() {
  disables_commit $'api 0\nui 0'
  mkdir -p services/api services/ui
  printf '{}\n' > services/api/eslint-suppressions.json
  printf '{}\n' > services/ui/eslint-suppressions.json
  git add -A
  git commit -q -m "[1] Freeze violations"
  expect_fail "$BIN/check-lint-disables.sh" "$REPO"
  expect_output "services/api/eslint-suppressions.json: tracked lint suppressions file; fix the violations and delete it"
  expect_output "services/ui/eslint-suppressions.json: tracked lint suppressions file"
}

# [repo-rules-7efca0]
test_no_suppressions_file_passes() {
  disables_commit "api 0"
  expect_pass "$BIN/check-lint-disables.sh" "$REPO"
}

test_untracked_suppressions_file_is_ignored() {
  disables_commit "api 0"
  mkdir -p services/api
  printf '{}\n' > services/api/eslint-suppressions.json
  expect_pass "$BIN/check-lint-disables.sh" "$REPO"
}

test_inline_and_file_failures_both_print() {
  disables_commit "api 0" services/api/src/a.ts
  printf '{}\n' > services/api/eslint-suppressions.json
  git add -A
  git commit -q -m "[1] Freeze violations"
  expect_fail "$BIN/check-lint-disables.sh" "$REPO"
  expect_output "api: 1 > 0 suppressions in bin/lint-disables.txt"
  expect_output "services/api/eslint-suppressions.json: tracked lint suppressions file"
}

test_no_services_and_empty_baseline_passes() {
  mkdir -p bin
  : > bin/lint-disables.txt
  git add bin/lint-disables.txt
  git commit -q -m "[1] Add an empty baseline"
  expect_pass "$BIN/check-lint-disables.sh" "$REPO"
}

# [repo-rules-fb5bf1]: only the generated contracts/ folder at a service's
# root is excluded, not a hand-written src/contracts/.
test_hand_written_contracts_code_is_counted() {
  disables_commit "api 0" services/api/src/contracts/a.ts
  expect_fail "$BIN/check-lint-disables.sh" "$REPO"
  expect_output "services/api/src/contracts/a.ts:1"
}
