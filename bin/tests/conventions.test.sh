# shellcheck shell=bash disable=SC2154,SC2016
# bin/check-conventions.sh: superpowers output, quoted numbers and gh without -R.

# write <path> <content>: create the file and stage it.
write() {
  mkdir -p "$(dirname "$1")"
  printf '%s\n' "$2" > "$1"
  git add -- "$1"
}

# expect_conventions_fail <path> <content> <output>: one file, one hit.
expect_conventions_fail() {
  write "$1" "$2"
  expect_fail "$BIN/check-conventions.sh" "$REPO"
  expect_output "$3"
  git rm -q --cached -- "$1"
  rm -- "$1"
}

# [repo-rules-64e3da]
test_superpowers_output_fails() {
  write docs/superpowers/specs/2026-11-06-topic-design.md '# Design'
  expect_fail "$BIN/check-conventions.sh" "$REPO"
  expect_output 'docs/superpowers/specs/2026-11-06-topic-design.md'
  expect_output 'design.md'
  expect_output 'tasks.md'
}

# [repo-rules-4451ca]
test_quoted_number_fails() {
  write compose.yml $'services:\n  MAX_TOKENS: "2000"'
  expect_fail "$BIN/check-conventions.sh" "$REPO"
  expect_output 'compose.yml:2:'
  expect_output 'unquoted'
  git rm -q --cached compose.yml
  expect_conventions_fail a.yaml $'items:\n  - \'15\'' 'a.yaml:2:'
  expect_conventions_fail .env.example 'PORT="8080"' '.env.example:1:'
  expect_conventions_fail b.yml 'RATIO: "0.5" # half' 'b.yml:1:'
}

# [repo-rules-32d0c8]
test_misread_values_stay_quoted() {
  write c.yml $'code: "0123"\npython-version: "3.10"\nport: 8080\nname: "2000 club"\nversion: "1.2.3"'
  expect_pass "$BIN/check-conventions.sh" "$REPO"
}

# [repo-rules-336b7d]
test_gh_without_repo_fails() {
  write .claude/skills/work/SKILL.md $'# Work\n\nSteps.\nRun `gh pr view 12 --json body`.'
  expect_fail "$BIN/check-conventions.sh" "$REPO"
  expect_output '.claude/skills/work/SKILL.md:4:'
  expect_output '-R "$(bin/repo)"'
  git rm -q --cached .claude/skills/work/SKILL.md
  expect_conventions_fail services/api/AGENTS.md 'Run `gh pr view 12 --json body`.' 'services/api/AGENTS.md:1:'
  expect_conventions_fail openspec/schemas/factory/schema.yaml 'instruction: run gh pr view 12 --json body' 'openspec/schemas/factory/schema.yaml:1:'
}

# [repo-rules-831c64]
test_gh_api_and_repo_pass() {
  write AGENTS.md $'Run `gh issue view 12 -R "$(bin/repo)"`.\nRun `gh api repos/factory/factory/pulls`.\nRun `gh pr checks --watch --repo "$(bin/repo)"`.\n`gh` reads `GH_REPO`.'
  write .claude/skills/openspec-x/SKILL.md 'Run gh pr view 1.'
  expect_pass "$BIN/check-conventions.sh" "$REPO"
}

test_conventions_usage() {
  local status=0
  "$BIN/check-conventions.sh" "$REPO/missing" > /dev/null 2>&1 || status=$?
  [ "$status" -eq 2 ] || fail "a missing root exited $status, expected 2"
  expect_pass "$BIN/check-conventions.sh" --help
  expect_output 'usage: bin/check-conventions.sh'
}

# [repo-rules-32d0c8]
test_conventions_string_marker_keeps_a_schema_string_quoted() {
  write compose.yml $'services:\n  a:\n    user: "1000" # string: Compose requires user to be a string'
  expect_pass "$BIN/check-conventions.sh" "$REPO"
  write compose.yml $'services:\n  a:\n    user: "1000" # a uid'
  expect_fail "$BIN/check-conventions.sh" "$REPO"
  expect_output '# string: <reason>'
}

# [repo-rules-336b7d]
test_conventions_gh_repo_checks_every_repository_command() {
  local sub
  for sub in 'secret set TOKEN' 'variable list' 'ruleset list' 'cache list' 'browse' 'co 12' 'attestation verify x'; do
    expect_conventions_fail AGENTS.md "Run \`gh $sub\`." 'AGENTS.md:1:'
  done
}

# [repo-rules-336b7d]
test_conventions_gh_repo_checks_each_command_on_a_line() {
  expect_conventions_fail AGENTS.md 'Run `gh pr view 1 -R "$(bin/repo)" && gh pr checks 1`.' 'AGENTS.md:1:'
  expect_conventions_fail AGENTS.md 'Run `gh pr checks 1` then `gh pr view 1 -R "$(bin/repo)"`.' 'AGENTS.md:1:'
}

# [repo-rules-831c64]
test_conventions_gh_repo_accepts_every_repo_flag_form() {
  write AGENTS.md $'Run `gh pr view 1 --repo="$(bin/repo)"`.\nRun `gh pr view 1 -R "$(bin/repo)"; gh run list -R "$(bin/repo)"`.\nRun `gh auth login` and `gh api user`; the gh command reads GH_REPO.'
  expect_pass "$BIN/check-conventions.sh" "$REPO"
}

# [repo-rules-32d0c8]
test_conventions_quoted_number_skips_block_scalars() {
  write .github/workflows/x.yml $'jobs:\n  a:\n    steps:\n      - run: |\n          cat > c.yml << EOF\n          port: "8080"\n          EOF\n      - run: >-\n          echo\n          - \'15\'\n      - name: "3"'
  expect_fail "$BIN/check-conventions.sh" "$REPO"
  expect_output '.github/workflows/x.yml:11:'
  [[ "$OUT" != *'x.yml:6:'* && "$OUT" != *'x.yml:10:'* ]] || fail "a block scalar line was flagged"$'\n'"$OUT"
  write .github/workflows/x.yml $'key: |\n  a: "1"\nnext:\n  b: "2"'
  expect_fail "$BIN/check-conventions.sh" "$REPO"
  expect_output 'x.yml:4:'
  [[ "$OUT" != *'x.yml:2:'* ]] || fail "a block scalar line was flagged"$'\n'"$OUT"
}

test_conventions_gh_repo_rejects_a_literal_repository() {
  expect_conventions_fail AGENTS.md 'Run `gh pr view 1 -R some-org/some-repo`.' 'AGENTS.md:1:'
  expect_conventions_fail AGENTS.md 'Run `gh pr view 1 --repo=some-org/some-repo`.' 'AGENTS.md:1:'
}
