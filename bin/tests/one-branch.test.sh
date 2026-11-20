# shellcheck shell=bash disable=SC2016 # literal backticks of markdown commands
# Tests that the workflow instructions run every change of an issue on one
# branch and one PR: the /work and /work-pr skills and AGENTS.md. Whether an
# agent follows them is model behaviour; these pin what the instructions say.

# expect_phrases <file> <phrase>... fails naming the first phrase <file> lacks.
expect_phrases() {
  local file="$1" phrase
  shift
  for phrase in "$@"; do
    grep -qF -- "$phrase" "$ROOT/$file" || fail "$file does not say: $phrase"
  done
}

# refuse_phrases <file> <phrase>... fails naming the first phrase <file> holds.
refuse_phrases() {
  local file="$1" phrase
  shift
  for phrase in "$@"; do
    ! grep -qF -- "$phrase" "$ROOT/$file" || fail "$file still says: $phrase"
  done
}

# [agent-workflow-604d98]
test_work_skill_keeps_every_change_on_one_branch() {
  expect_phrases .claude/skills/work/SKILL.md \
    'one branch' 'plain `## Changes` list' 'bin/openspec-change-id.sh' 'on the same branch' '`/work-pr` runs once' \
    'against the earlier change'\''s delta' 'the commit hook prefixes the first change'\''s hash'
  refuse_phrases .claude/skills/work/SKILL.md 'gh stack' '(stack)' '(parallel)' 'Parallel'
}

# [agent-workflow-4cb236]
test_pr_skill_archives_every_change_into_one_pr() {
  expect_phrases .claude/skills/work-pr/SKILL.md \
    '`openspec/changes/<issue>-*`' 'one archive commit per change' 'Closes #<ISSUE_NUMBER>' 'every change ID' 'in the order of the issue'\''s breakdown'
  refuse_phrases .claude/skills/work-pr/SKILL.md 'gh stack' 'Part of #'
}

# [agent-workflow-9e4533]
test_pr_skill_reruns_failed_jobs_before_pushing_a_fix() {
  expect_phrases .claude/skills/work-pr/SKILL.md \
    'every failed job' '`.github/workflows/checks.yml`' 'locally' 'push only once they pass' \
    'cancels the stale run' 'cannot run on this machine' 'hand-over'
  refuse_phrases .claude/skills/work-pr/SKILL.md 'commit with the same prefix, push, and watch again'
}

# [repo-rules-e81bfb]
test_agents_md_forbids_force_push() {
  local safety
  safety="$(sed -n '/^## Safety/,/^## [^S]/p' "$ROOT/AGENTS.md")"
  [[ "$safety" == *'Never force-push'* ]] || fail 'AGENTS.md Safety does not say: Never force-push'
  [[ "$safety" == *'Never push to `main`'* ]] || fail 'AGENTS.md Safety does not keep main never pushed'
  [[ "$safety" == *'is a human'\''s call'* ]] || fail 'AGENTS.md Safety does not hand a pushed-history rewrite to a human'
  expect_phrases AGENTS.md 'bin/e2e --proof --change <id>' 'Closes #<issue>' 'any change of the branch'\''s issue'
  refuse_phrases AGENTS.md 'gh stack' 'Part of #'
}

# [repo-rules-fbb29c]
test_agents_md_runs_a_multi_change_issue_on_one_branch() {
  expect_phrases AGENTS.md "An issue's changes share one branch and one PR"
  refuse_phrases AGENTS.md 'gh stack'
}

# [agent-workflow-3befd9]
test_work_claims_issue_and_records_starter() {
  expect_phrases .claude/skills/work/SKILL.md \
    'bin/issue-start <N>' 'exits 3' 'ask the user whether to take it over' '--take-over' \
    'Started by @<login> on branch `<branch>`' 'update that line'
}

# [repo-rules-e74c70]
test_agents_md_forbids_loosening_a_check() {
  local section
  section="$(sed -n '/^## Definition of done/,/^## Safety/p' "$ROOT/AGENTS.md")"
  [[ "$section" == *'Never edit a test, a `NO E2E` exclusion, a ratchet or a suppression file'*'to make a check pass'* ]] ||
    fail 'Definition of done does not forbid loosening a check'
  [[ "$section" == *'stop and report'* ]] || fail 'Definition of done does not say stop and report'
  [[ "$section" == *'Lowering a ratchet after a real fix'* ]] || fail 'Definition of done no longer allows lowering a ratchet'
  expect_phrases .claude/skills/work-pr/SKILL.md 'AGENTS.md → "Definition of done"'
  refuse_phrases .claude/skills/work-pr/SKILL.md 'Never skip, disable or loosen a check to get green'
}

# [agent-workflow-26e0f8]
test_pr_skill_verifies_each_change_before_archiving() {
  local skill=.claude/skills/work-pr/SKILL.md verify archive
  expect_phrases "$skill" '`/opsx:verify <change-id>`' 'every CRITICAL issue' 'before archiving it'
  verify="$(grep -nF '/opsx:verify <change-id>' "$ROOT/$skill" | head -1 | cut -d: -f1)"
  archive="$(grep -nF 'bin/openspec-archive <change-id>' "$ROOT/$skill" | head -1 | cut -d: -f1)"
  [ "$verify" -lt "$archive" ] || fail "$skill archives a change before verifying it"
}

# [agent-workflow-901f28]
test_pr_skill_reviews_the_branch_once_with_a_fresh_reviewer() {
  expect_phrases .claude/skills/work-pr/SKILL.md \
    '`superpowers:requesting-code-review`' '`origin/main..HEAD`' 'once, after archiving and before the draft PR' \
    'most capable model' 'not the implementer'\''s conclusions'
}

# [agent-workflow-d6c988]
test_pr_skill_reviews_without_subagents_in_a_fresh_session() {
  expect_phrases .claude/skills/work-pr/SKILL.md \
    'cannot dispatch a subagent' 'fresh non-interactive session' 'read-only' 'stop and ask the human'
}

# [agent-workflow-3f3fda]
test_pr_skill_fixes_serious_findings_test_first() {
  expect_phrases .claude/skills/work-pr/SKILL.md \
    'every Critical and Important finding' 'fixed test-first' 'before the draft PR opens'
}

# [agent-workflow-6f3964]
test_pr_body_carries_a_review_section() {
  expect_phrases .claude/skills/work-pr/SKILL.md '## Review' 'deferred with a reason' 'No findings.'
}

# [agent-workflow-3f3fda] Review fixes land on top of the archives, and the
# rules say so instead of calling the archives the PR's last commits.
test_agents_md_puts_review_fixes_on_top_of_the_archives() {
  refuse_phrases AGENTS.md 'as the PR'\''s last commits;' 'archive every change as the last commits, one review'
  expect_phrases AGENTS.md 'followed only by review fixes'
}

# [agent-workflow-901f28] The review range is cut from a freshly fetched main.
test_pr_skill_fetches_main_before_the_review_range() {
  expect_phrases .claude/skills/work-pr/SKILL.md 'git fetch origin main'
}
