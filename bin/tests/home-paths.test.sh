# shellcheck shell=bash disable=SC2154
# bin/check-home-paths.sh: personal home-directory paths in the files every
# teammate's agent reads.

# write <path> <content>: create the file and stage it.
write() {
  mkdir -p "$(dirname "$1")"
  printf '%s\n' "$2" > "$1"
  git add -- "$1"
}

# [repo-rules-c20195]
test_tracked_home_path_fails() {
  write AGENTS.md $'# Agents\n\nConfig lives in `/home/bob/.config/tool`.'
  expect_fail "$BIN/check-home-paths.sh"
  expect_output 'AGENTS.md:3: /home/bob'
  expect_output 'relative to the repository'
}

# [repo-rules-d539ba]
test_non_personal_paths_pass() {
  write docs/a.md $'See src/pages/home/HomePage.tsx and `/Users/<name>/`.\nSessions live in ~/.factory/sessions.\nhttps://example.com/home/alice'
  write openspec/changes/archive/2026-01-01-1-abc123-x/design.md 'Notes live in /home/factory/notes.'
  write .claude/skills/openspec-apply-change/SKILL.md 'Copied from /Users/alice/x.'
  write bin/tests/x.sh 'HOME_DIR=/Users/alice/x'
  expect_pass "$BIN/check-home-paths.sh"
}

test_home_paths_cover_every_instruction_file() {
  write openspec/changes/1-abc123-x/tasks.md 'See /Users/alice/notes.md.'
  write services/api/AGENTS.md 'Run /home/bob/x first.'
  write .claude/skills/work/SKILL.md 'Open C:\Users\carol\x.'
  write 'docs/my notes.md' 'From (/Users/dan/y).'
  expect_fail "$BIN/check-home-paths.sh"
  expect_output 'openspec/changes/1-abc123-x/tasks.md:1: /Users/alice'
  expect_output 'services/api/AGENTS.md:1: /home/bob'
  expect_output '.claude/skills/work/SKILL.md:1: C:\Users\carol'
  expect_output 'docs/my notes.md:1: /Users/dan'
}

test_home_paths_staged_checks_the_index_copy() {
  write docs/a.md 'Notes in /Users/alice/x.'
  printf 'Clean now.\n' > docs/a.md
  expect_pass "$BIN/check-home-paths.sh"
  expect_fail "$BIN/check-home-paths.sh" --staged
  expect_output 'docs/a.md:1: /Users/alice'
}

test_home_paths_reads_standard_input() {
  OUT="$(printf 'ok\n/Users/alice/x\n' | "$BIN/check-home-paths.sh" - 2>&1)" && fail "stdin with a home path passed: $OUT"
  expect_output '<stdin>:2: /Users/alice'
  OUT="$(printf 'ok\r\nproof/shot.png\r\n' | "$BIN/check-home-paths.sh" - 2>&1)" || fail "clean stdin failed: $OUT"
}

test_home_paths_usage() {
  local status=0
  "$BIN/check-home-paths.sh" --bogus > /dev/null 2>&1 || status=$?
  [ "$status" -eq 2 ] || fail "--bogus exited $status, expected 2"
  expect_pass "$BIN/check-home-paths.sh" --help
  expect_output 'usage: bin/check-home-paths.sh'
}

# [repo-rules-98a0c5]
test_home_paths_inside_file_urls_fail() {
  OUT="$(printf '![shot](file:///Users/alice/shot.png)\n' | "$BIN/check-home-paths.sh" - 2>&1)" && fail "a file:// home path passed: $OUT"
  expect_output '<stdin>:1: /Users/alice'
}

test_home_paths_report_only_the_path_after_a_multibyte_character() {
  local locale
  for locale in C en_US.UTF-8 C.UTF-8; do
    OUT="$(printf 'Notes —/Users/alice/x\n' | LC_ALL="$locale" "$BIN/check-home-paths.sh" - 2> /dev/null)" && fail "$locale: an em-dashed home path passed"
    [ "$OUT" = '<stdin>:1: /Users/alice' ] || fail "$locale: printed $(printf '%s' "$OUT" | od -c)"
  done
}
