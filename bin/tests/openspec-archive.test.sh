# shellcheck shell=bash disable=SC2154
# bin/openspec-archive

CHANGE=9-abcdef-x

# tasks <content>: write the change's tasks.md and point OPENSPEC at a stub
# that records its arguments.
tasks() {
  mkdir -p "openspec/changes/$CHANGE"
  printf '%s\n' "$1" > "openspec/changes/$CHANGE/tasks.md"
  printf '#!/usr/bin/env bash\necho "$*" > "%s/openspec-args"\n' "$PWD" > openspec-stub
  chmod +x openspec-stub
  export OPENSPEC="$PWD/openspec-stub"
}

archive() { "$BIN/openspec-archive" "$@"; }

not_archived() { [ ! -e openspec-args ] || fail "openspec archive ran: $(cat openspec-args)"; }

# [spec-coverage-b1f5d7]
test_unchecked_task_refuses() {
  tasks $'## 1. Work\n\n- [ ] 1.2 Do it\n- [x] 1.3 Done'
  expect_fail archive "$CHANGE"
  expect_output "tasks.md:3: - [ ] 1.2 Do it"
  expect_output "Refusing to archive $CHANGE: 1 unfinished task(s)"
  not_archived
}

# [spec-coverage-b1f5d7]
test_nested_and_other_markers_count() {
  tasks $'- [x] 1.1 Parent\n  - [ ] 1.1.1 sub\n+ [~] two\n1. [] three\n- [ x ] four\n- [A](./a.md)\n* [X] five'
  expect_fail archive "$CHANGE"
  expect_output "tasks.md:2:   - [ ] 1.1.1 sub"
  expect_output "tasks.md:3: + [~] two"
  expect_output "tasks.md:4: 1. [] three"
  expect_output "3 unfinished task(s)"
  [[ "$OUT" != *four* && "$OUT" != *a.md* && "$OUT" != *five* ]] || fail "a done task or a link was reported"$'\n'"$OUT"
  not_archived
}

# [spec-coverage-b1f5d7]
test_crlf_tasks_parse() {
  tasks $'- [x] 1.1 Done\r\n- [ ] 1.2 Open\r'
  expect_fail archive "$CHANGE"
  expect_output "tasks.md:2: - [ ] 1.2 Open"
  not_archived
}

# [spec-coverage-f94993]
test_finished_change_is_archived() {
  tasks $'- [x] 1.1 Done\n  - [X] 1.1.1 Also done'
  expect_pass archive "$CHANGE"
  [ "$(cat openspec-args)" = "archive $CHANGE --yes" ] || fail "unexpected arguments: $(cat openspec-args)"
}

# [spec-coverage-1d435f]
test_dropped_with_reason_archives() {
  tasks $'- [x] 2.1 [repo] Dropped: covered by e2e. Write tests\n- [x] 2.2 Dropped: not needed.'
  expect_pass archive "$CHANGE"
  [ -e openspec-args ] || fail "openspec archive did not run"
}

# [spec-coverage-0e7bab]
test_dropped_without_reason_refuses() {
  tasks $'- [x] 2.1 Dropped:\n- [x] 2.2 [repo] Dropped: .\n- [x] 2.3 Done'
  expect_fail archive "$CHANGE"
  expect_output "tasks.md:1: - [x] 2.1 Dropped:"
  expect_output "tasks.md:2: - [x] 2.2 [repo] Dropped: ."
  expect_output "dropped without a reason"
  not_archived
}

test_openspec_archive_bad_arguments() {
  tasks '- [x] 1.1 Done'
  expect_fail archive
  expect_output "usage:"
  expect_fail archive 9-abcdef-missing
  expect_output "No change openspec/changes/9-abcdef-missing"
  expect_pass archive --help
  expect_output "usage:"
  not_archived
}

test_openspec_archive_exit_codes() {
  tasks '- [ ] 1.1 Open'
  set +e
  archive "$CHANGE" >/dev/null 2>&1
  [ $? -eq 1 ] || fail "refusal does not exit 1"
  archive >/dev/null 2>&1
  [ $? -eq 2 ] || fail "missing argument does not exit 2"
  archive 9-abcdef-missing >/dev/null 2>&1
  [ $? -eq 2 ] || fail "unknown change does not exit 2"
  set -e
}
