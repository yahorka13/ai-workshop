# shellcheck shell=bash disable=SC2154
# bin/check-eof-newline.sh

eof() { "$BIN/check-eof-newline.sh" "$@"; }

# [repo-rules-ec4393]
test_missing_final_newline_is_rejected() {
  printf 'hello' > a.txt
  printf 'ok\n' > b.txt
  expect_fail eof a.txt b.txt
  expect_output "a.txt: missing newline at end of file"
  [[ "$OUT" != *b.txt* ]] || fail "b.txt was reported"
}

# [repo-rules-82eeee]
test_well_formed_empty_binary_and_deleted_files_pass() {
  printf 'ok\n' > good.txt
  : > empty.txt
  printf 'PNG\000\001\002' > image.png
  expect_pass eof good.txt empty.txt image.png gone.txt
}

# [repo-rules-82eeee]
test_no_paths_passes() {
  expect_pass eof
}

test_symlinks_are_skipped() {
  ln -s target-without-newline link
  expect_pass eof link
  git add link
  expect_pass eof --staged link
}

test_staged_mode_reads_the_index() {
  printf 'hello' > a.txt
  git add a.txt
  printf 'hello\n' > a.txt
  expect_fail eof --staged a.txt
  expect_output "a.txt: missing newline at end of file"
  expect_pass eof a.txt
}

test_large_files_are_checked() {
  head -c 200000 /dev/zero | tr '\000' 'x' > big.txt
  expect_fail eof big.txt
  echo >> big.txt
  expect_pass eof big.txt
}

test_paths_with_spaces_and_unicode() {
  mkdir -p "docs/a b"
  printf 'no newline' > "docs/a b/é.md"
  git add -- "docs/a b/é.md"
  expect_fail "$BIN/check-eof-newline.sh" "docs/a b/é.md"
  expect_output "a b/"
  printf '\n' >> "docs/a b/é.md"
  expect_pass "$BIN/check-eof-newline.sh" "docs/a b/é.md"
}

# [repo-rules-2c7244]
test_glob_like_path_is_read_literally() {
  printf 'ok\n' > a.txt
  git add a.txt
  expect_pass eof --staged '*.txt'
  [ -z "$OUT" ] || fail "unexpected output: $OUT"
}

test_literal_bracket_name_is_checked() {
  printf 'no newline' > '[ab].txt'
  printf 'ok\n' > a.txt
  git add -- '[ab].txt' a.txt
  expect_fail eof --staged '[ab].txt'
  expect_output "[ab].txt: missing newline at end of file"
}
