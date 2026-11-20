# shellcheck shell=bash disable=SC2154
# bin/ci-eof-newline.sh: CI's eof-newline step over a pull request or a push.

ci_eof() { "$BIN/ci-eof-newline.sh" "$@"; }

# old_commit: a tracked old.txt without a final newline, committed.
old_commit() {
  printf 'old' > old.txt
  git add old.txt
  git commit -q -m "[1] Old"
}

# [ci-3c9837]
test_only_changed_files_are_checked() {
  old_commit
  printf 'new' > "new file.txt"
  git add "new file.txt"
  git commit -q -m "[1] New"
  expect_fail ci_eof HEAD~1 HEAD
  expect_output "new file.txt: missing newline at end of file"
  [[ "$OUT" != *old.txt* ]] || fail "old.txt was reported: $OUT"
}

# [ci-a31d7f]
test_first_push_checks_every_tracked_file() {
  old_commit
  expect_fail ci_eof 0000000000000000000000000000000000000000 HEAD
  expect_output "old.txt: missing newline at end of file"
  expect_fail ci_eof "" HEAD
  expect_output "old.txt: missing newline at end of file"
}

test_clean_range_passes() {
  old_commit
  printf 'ok\n' > b.txt
  git add b.txt
  git commit -q -m "[1] B"
  expect_pass ci_eof HEAD~1 HEAD
}

test_deleted_file_is_not_checked() {
  old_commit
  git rm -q old.txt
  git commit -q -m "[1] Remove"
  expect_pass ci_eof HEAD~1 HEAD
}

test_wrong_arguments_exit_2() {
  local status=0
  "$BIN/ci-eof-newline.sh" HEAD > /dev/null 2>&1 || status=$?
  [ "$status" -eq 2 ] || fail "expected exit 2, got $status"
}
