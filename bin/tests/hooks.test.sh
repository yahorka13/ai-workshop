# shellcheck shell=bash disable=SC2154
# .githooks/ and bin/setup-git-hooks.sh

# Commit this repository's scripts and hooks into the test repo, enable the
# hooks, and switch to <branch>.
with_hooks() {
  cp -R "$ROOT/bin" "$ROOT/.githooks" .
  git add bin .githooks
  git commit -q --no-verify -m "[1] Add tooling"
  bin/setup-git-hooks.sh > /dev/null
  git checkout -q -b "$1"
}

expect_subject() {
  local actual
  actual="$(git log -1 --format=%s)"
  [ "$actual" = "$1" ] || fail "expected subject '$1', got '$actual'"
}

# [repo-rules-6b931f]
test_setup_installs_hooks_idempotently() {
  cp -R "$ROOT/bin" "$ROOT/.githooks" .
  expect_pass bin/setup-git-hooks.sh
  expect_output "core.hooksPath=.githooks"
  expect_pass bin/setup-git-hooks.sh
  [ "$(git config core.hooksPath)" = ".githooks" ] || fail "core.hooksPath is '$(git config core.hooksPath)'"
}

# [repo-rules-6b931f]
test_hooks_apply_in_linked_worktrees() {
  with_hooks main-tools
  git worktree add -q -b 3-fix-typo "$REPO/wt"
  (cd "$REPO/wt" && git commit -q --allow-empty -m "Fix typo")
  [ "$(git log -1 --format=%s 3-fix-typo)" = "[3] Fix typo" ] || fail "worktree commit was not prefixed"
}

# [repo-rules-126d5f]
test_prefix_is_added_from_the_branch() {
  with_hooks 1-a38e64-git-hooks
  expect_pass git commit -q --allow-empty -m "Add hooks"
  expect_subject "[1][a38e64] Add hooks"
  git checkout -q -b 12-fix-typo
  expect_pass git commit -q --allow-empty -m "Fix typo"
  expect_subject "[12] Fix typo"
}

# [repo-rules-b22c7d]
test_existing_prefix_is_not_doubled() {
  with_hooks 1-a38e64-git-hooks
  expect_pass git commit -q --allow-empty -m "[1][a38e64] Add hooks"
  expect_subject "[1][a38e64] Add hooks"
}

# [repo-rules-b22c7d]
test_amend_keeps_the_message() {
  with_hooks 1-a38e64-git-hooks
  git commit -q --allow-empty -m "Add hooks"
  expect_pass git commit -q --amend --allow-empty --no-edit
  expect_subject "[1][a38e64] Add hooks"
}

# [repo-rules-b22c7d]
test_merge_keeps_gits_subject() {
  with_hooks 1-a38e64-git-hooks
  git checkout -q -b side
  git commit -q --allow-empty -m "[1][a38e64] Add side"
  git checkout -q 1-a38e64-git-hooks
  git commit -q --allow-empty -m "Add main"
  expect_pass git merge -q --no-ff --no-edit side
  expect_subject "Merge branch 'side' into 1-a38e64-git-hooks"
}

# [repo-rules-46cbe1]
test_malformed_subject_is_rejected_at_commit_time() {
  with_hooks feature-x
  expect_fail git commit -q --allow-empty -m "fix stuff"
  expect_output "Bad commit subject: fix stuff"
  expect_pass git commit -q --allow-empty -m "[HOTFIX] Fix stuff"
}

# [repo-rules-b54e71]
test_staged_file_without_final_newline_is_rejected() {
  with_hooks 1-a38e64-git-hooks
  printf 'hello' > "my notes.txt"
  git add "my notes.txt"
  printf 'hello\n' > "my notes.txt"
  expect_fail git commit -q -m "Add notes"
  expect_output "my notes.txt: missing newline at end of file"
  git add "my notes.txt"
  expect_pass git commit -q -m "Add notes"
  expect_subject "[1][a38e64] Add notes"
}

# [repo-rules-7c7601]
test_local_hook_accepts_fixup_commits() {
  with_hooks 1-a38e64-git-hooks
  git commit -q --allow-empty -m "Add hooks"
  expect_pass git commit -q --allow-empty --fixup HEAD
  expect_subject "fixup! [1][a38e64] Add hooks"
}

test_prefix_only_message_is_rejected() {
  with_hooks 1-a38e64-git-hooks
  expect_fail git commit -q --allow-empty
  expect_output "uppercase letter"
  [ "$(git log -1 --format=%s)" = "[1] Add tooling" ] || fail "a commit was created"
}

test_detached_head_gets_no_prefix_but_accepts_valid_subjects() {
  with_hooks 1-a38e64-git-hooks
  git checkout -q --detach
  expect_fail git commit -q --allow-empty -m "Add detached"
  expect_pass git commit -q --allow-empty -m "[1][a38e64] Add detached"
}

# [repo-rules-7c7601]
test_local_hook_accepts_amend_fixups() {
  with_hooks 1-a38e64-git-hooks
  git commit -q --allow-empty -m "Add hooks"
  expect_pass git commit -q --allow-empty --fixup=amend:HEAD
  expect_subject "amend! [1][a38e64] Add hooks"
}

# [repo-rules-b9098e]
test_pre_commit_commits_and_pushes_the_fix() {
  with_hooks 1-fix-newline
  git init -q --bare "$REPO/remote.git"
  git remote add origin "$REPO/remote.git"
  printf 'CREATE TABLE "probe" ();' > generated.sql
  printf 'already fine\n' > fine.txt
  git add generated.sql fine.txt
  expect_pass git commit -m "[1] Add generated output"
  expect_output "added the missing final newline to generated.sql"
  [ -n "$(git show HEAD:generated.sql | tail -c1)" ] && fail "the committed file still lacks its newline"
  [ "$(git show HEAD:fine.txt)" = "already fine" ] || fail "an already-correct file was changed"
  [ -z "$(git status --porcelain -- generated.sql)" ] || fail "the fix was left out of the commit"
  expect_pass git push -q origin HEAD:refs/heads/1-fix-newline
  [ -n "$(git --git-dir="$REPO/remote.git" show 1-fix-newline:generated.sql | tail -c1)" ] && fail "the pushed file lacks its newline"
  true
}

# [repo-rules-fd2681]
test_pre_commit_leaves_binary_and_partial_files_alone() {
  with_hooks 1-leave-alone
  printf 'PNG\000\001\002' > image.png
  git add image.png
  expect_pass git commit -m "[1] Add an image"
  [ "$(git show HEAD:image.png | wc -c | tr -d ' ')" = 6 ] || fail "the image was modified"
  # Staged content that differs from the working tree is never completed
  # silently: the check rejects it instead.
  printf 'staged without newline' > partial.txt
  git add partial.txt
  printf 'working copy has more\n' > partial.txt
  expect_fail git commit -m "[1] Add a partially staged file"
  expect_output "missing newline at end of file"
}

# [repo-rules-72a7e8]
test_commit_adding_a_home_path_is_refused() {
  with_hooks 1-abc123-x
  mkdir -p openspec/changes/1-abc123-x
  echo 'See /Users/alice/notes.md' > openspec/changes/1-abc123-x/tasks.md
  git add openspec/changes/1-abc123-x/tasks.md
  expect_fail git commit -q -m "Add plan"
  expect_output 'openspec/changes/1-abc123-x/tasks.md:1: /Users/alice'
  expect_output 'relative to the repository'
  [ "$(git rev-list --count HEAD)" -eq 2 ] || fail 'the commit was created'
}

# with_remote <branch>: with_hooks on <branch> and a bare origin.
with_remote() {
  with_hooks "$1"
  git init -q --bare "$REPO/remote.git"
  git remote add origin "$REPO/remote.git"
}

# seed <ref>: put HEAD on the remote's <ref> without running the hooks.
seed() { git -c core.hooksPath=/dev/null push -q origin "HEAD:refs/heads/$1"; }

remote_sha() { git --git-dir="$REPO/remote.git" rev-parse "refs/heads/$1"; }

# [repo-rules-dce864]
test_force_push_is_refused() {
  with_remote 12-x
  seed 12-x
  local old
  old="$(remote_sha 12-x)"
  git commit -q --amend -m "[12] Changed"
  expect_fail git push -q origin +12-x
  expect_output 'refusing a force-push to 12-x'
  expect_output 'merge origin/main'
  [ "$(remote_sha 12-x)" = "$old" ] || fail 'the remote branch moved'
}

# [repo-rules-72abe8]
test_fast_forward_and_new_branches_pass() {
  with_remote 12-x
  expect_pass git push -q origin 12-x
  git commit -q --allow-empty -m "[12] More"
  expect_pass git push -q origin 12-x
  git tag v1
  expect_pass git push -q origin v1
}

test_push_to_main_is_refused() {
  with_remote 12-x
  expect_fail git push -q origin HEAD:main
  expect_output 'main'
  expect_output 'through a pull request'
  expect_output 'FACTORY_PUSH_PROTECTED=1 git push'
  seed main
  expect_fail git push -q origin :main
  seed 12-y
  expect_pass git push -q origin :12-y
}

test_deliberate_push_to_main_passes() {
  with_remote 12-x
  OUT="$(FACTORY_PUSH_PROTECTED=1 git push -q origin HEAD:main 2>&1)" || fail "the deliberate push to main was refused: $OUT"
}

# [repo-rules-407e29]
test_variable_does_not_allow_force() {
  with_remote 12-x
  seed main
  git commit -q --amend -m "[12] Changed"
  if OUT="$(FACTORY_PUSH_PROTECTED=1 git push -q origin +HEAD:main 2>&1)"; then
    fail "the force-push to main passed: $OUT"
  fi
  expect_output 'refusing a force-push to main'
}

test_pre_push_unknown_remote_sha_is_refused() {
  with_remote 12-x
  OUT="$(printf 'refs/heads/12-x %s refs/heads/12-x %s\n' "$(git rev-parse HEAD)" 0123456789abcdef0123456789abcdef01234567 |
    .githooks/pre-push origin "$REPO/remote.git" 2>&1)" && fail "an unknown remote commit passed: $OUT"
  expect_output '12-x has commits this clone does not have'
  expect_output 'git fetch origin && git merge origin/12-x'
}

test_pre_push_one_refused_line_refuses_the_push() {
  with_remote 12-x
  local zero=0000000000000000000000000000000000000000 head
  head="$(git rev-parse HEAD)"
  OUT="$(printf 'refs/heads/12-x %s refs/heads/12-x %s\nrefs/heads/12-x %s refs/heads/main %s\n' "$head" "$zero" "$head" "$zero" |
    .githooks/pre-push origin "$REPO/remote.git" 2>&1)" && fail "a push with a main line passed: $OUT"
  expect_output 'refusing a push to main'
}


# hooks_spec_tree: a widgets spec with one single-obligation requirement,
# committed.
hooks_spec_tree() {
  mkdir -p openspec/specs/widgets
  printf '# widgets Specification\n\n## Purpose\nThe widgets of the fixtures for the pre-commit obligation tests.\n\n## Requirements\n\n### Requirement: Widgets spin\nA widget SHALL spin.\n\n#### Scenario: [widgets-a00001] Spin\n- **WHEN** on\n- **THEN** spin\n' > openspec/specs/widgets/spec.md
  git add openspec
  git commit -q --no-verify -m "[1] Add specs"
}

# hooks_bundled_change: an active change adding a requirement with two
# obligations, not staged.
hooks_bundled_change() {
  mkdir -p openspec/changes/1-abc123-x/specs/widgets
  printf 'schema: spec-driven\n' > openspec/changes/1-abc123-x/.openspec.yaml
  printf '# Proposal\n\n## Why\nThe pre-commit fixtures need a change that bundles two obligations.\n\n## What Changes\n- Hum.\n' > openspec/changes/1-abc123-x/proposal.md
  printf '# Spec Delta\n\n## ADDED Requirements\n\n### Requirement: Widgets hum\nA widget SHALL hum. It SHALL hum quietly.\n\n#### Scenario: [widgets-a00002] Hum\n- **WHEN** on\n- **THEN** hum\n' > openspec/changes/1-abc123-x/specs/widgets/spec.md
}

# [spec-tools-53b52e]
test_precommit_rejects_a_bundled_requirement() {
  with_hooks 1-abc123-x
  hooks_spec_tree
  hooks_bundled_change
  git add openspec
  expect_fail git commit -q -m "Add humming"
  expect_output 'Widgets hum has 2 obligations'
  [ "$(git rev-list --count HEAD)" -eq 3 ] || fail 'the commit was created'
}

# [spec-tools-afc18b]
test_precommit_skips_the_check_without_spec_files() {
  with_hooks 1-abc123-x
  hooks_spec_tree
  # The bundled change would fail the check; a commit without spec files never runs it.
  hooks_bundled_change
  printf 'notes\n' > notes.txt
  git add notes.txt
  expect_pass git commit -q -m "Add notes"
}

# A commit staging thousands of spec files still runs the
# check: the list of staged paths is longer than a pipe holds.
# [spec-tools-53b52e]
test_precommit_checks_a_large_spec_commit() {
  local i
  with_hooks 1-abc123-x
  hooks_spec_tree
  hooks_bundled_change
  mkdir -p openspec/changes/archive/a-long-archive-folder-name-for-the-hook-test
  for i in $(seq 1 3000); do
    : > "openspec/changes/archive/a-long-archive-folder-name-for-the-hook-test/file-$i.md"
  done
  git add openspec
  expect_fail git commit -q -m "Archive many files"
  expect_output 'Widgets hum has 2 obligations'
}

# No hook and no CI step calls a check-leaks script.
test_hooks_name_no_leak_check() {
  local file
  for file in "$ROOT"/.githooks/* "$ROOT/.github/workflows/checks.yml"; do
    ! grep -nE 'check-leaks|LEAK_TERMS' "$file" || fail "${file#"$ROOT"/} calls a check-leaks script"
  done
}
