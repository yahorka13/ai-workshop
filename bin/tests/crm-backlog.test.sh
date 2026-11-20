# shellcheck shell=bash disable=SC2154
# bin/crm-backlog and the /crm-backlog skill. A fake `gh` answers
# `repo view` from $FAKE_TEMPLATE, `issue list` from $FAKE_ISSUES (lines of
# <number><TAB><title>) and `label list` from $FAKE_LABELS; `label create`
# fails when $FAKE_LABEL_RACES is set, as if another run had just created the
# label; `issue create` keeps its body in bodies/<n>.md, numbers issues from
# $FAKE_NEXT (default 41) and fails on the title in $FAKE_CREATE_FAILS. Every
# call is logged to gh.log, one line per call with each argument in brackets.

crm_fixture() {
  mkdir -p fake-bin bin bodies .claude/skills/crm-backlog/issues
  cp "$BIN/crm-backlog" "$BIN/repo" bin/ 2> /dev/null || true
  cat > fake-bin/gh <<'GH'
#!/usr/bin/env bash
{ printf '[%s]' "$@"; echo; } >> gh.log
case "$1 $2" in
  "repo view")
    [ -z "${FAKE_VIEW_FAILS:-}" ] || { echo "HTTP 401: Bad credentials" >&2; exit 1; }
    echo "${FAKE_TEMPLATE:-false}" ;;
  "issue list") [ -z "${FAKE_ISSUES:-}" ] || printf '%s\n' "$FAKE_ISSUES" ;;
  "label list")
    [ ! -f raced ] || echo crm
    [ -z "${FAKE_LABELS:-}" ] || printf '%s\n' "$FAKE_LABELS" ;;
  "label create")
    [ -z "${FAKE_LABEL_RACES:-}" ] || { touch raced; echo "label with name \"$3\" already exists" >&2; exit 1; } ;;
  "issue create")
    title='' body=''
    while [ $# -gt 0 ]; do
      case "$1" in
        --title) title="$2"; shift ;;
        --body-file) body="$2"; shift ;;
      esac
      shift
    done
    [ "$title" != "${FAKE_CREATE_FAILS:-}" ] || { echo "HTTP 502" >&2; exit 1; }
    n="$(cat next 2> /dev/null || echo "${FAKE_NEXT:-41}")"
    cp "$body" "bodies/$n.md"
    echo $((n + 1)) > next
    if [ -n "${FAKE_CREATE_JUNK:-}" ]; then echo "Creating issue in o/r"; else echo "https://github.com/o/r/issues/$n"; fi ;;
  *) echo "unexpected: gh $*" >&2; exit 1 ;;
esac
GH
  chmod +x fake-bin/gh
  PATH="$PWD/fake-bin:$PATH"
  : > gh.log
  git remote add origin git@github.com:o/r.git
  export FAKE_TEMPLATE=false FAKE_ISSUES='' FAKE_LABELS=bug
  issue_file 01-a A
  issue_file 02-b B 01-a
  issue_file 03-c C 01-a 02-b
}

# issue_file <slug> <title> [<after slug>...] writes a small ticket.
issue_file() {
  local slug="$1" title="$2" dep
  shift 2
  {
    echo "# $title"
    for dep in "$@"; do echo "after: $dep"; done
    printf '\n## Problem\n\n%s is missing.\n\n## What we want\n\n%s.\n\n## Scope\n\nOnly %s.\n' "$title" "$title" "$title"
  } > ".claude/skills/crm-backlog/issues/$slug.md"
}

crm_backlog() { bin/crm-backlog "$@"; }

created() { grep -c '^\[issue\]\[create\]' gh.log || true; }

no_writes() {
  ! grep -qE '^\[(issue|label)\]\[create\]' gh.log || fail "expected no writes"$'\n'"$(cat gh.log)"
}

# [agent-workflow-74af2b]
test_empty_repository_gets_the_backlog() {
  crm_fixture
  expect_pass crm_backlog
  expect_output "filed #41 A"
  expect_output "filed #42 B"
  expect_output "filed #43 C"
  grep -qF '[label][create][crm][-R][o/r]' gh.log || fail "label not created"$'\n'"$(cat gh.log)"
  [ "$(grep -n '^\[label\]\[create\]' gh.log | cut -d: -f1)" -lt "$(grep -n '^\[issue\]\[create\]' gh.log | head -n 1 | cut -d: -f1)" ] ||
    fail "the label must exist before the first issue"
  [ "$(grep '^\[issue\]\[create\]' gh.log | grep -c '\[--label\]\[crm\]')" -eq 3 ] || fail "every issue is labelled crm"
  grep '^\[issue\]\[create\]' gh.log | grep -o '\[--title\]\[[^]]*\]' | tr -d '\n' | grep -qF '[--title][A][--title][B][--title][C]' ||
    fail "issues are not filed in file order"$'\n'"$(cat gh.log)"
}

# [agent-workflow-a24e73]
test_label_race_does_not_fail() {
  crm_fixture
  FAKE_LABEL_RACES=1 expect_pass crm_backlog
  [ "$(created)" -eq 3 ] || fail "expected 3 issues"
}

# [agent-workflow-ae4bb4]
test_after_lines_become_issue_numbers() {
  crm_fixture
  expect_pass crm_backlog
  grep -qx 'after: #41' bodies/42.md || fail "B does not depend on #41"$'\n'"$(cat bodies/42.md)"
  grep -qx 'after: #41' bodies/43.md || fail "C does not depend on #41"$'\n'"$(cat bodies/43.md)"
  grep -qx 'after: #42' bodies/43.md || fail "C does not depend on #42"$'\n'"$(cat bodies/43.md)"
  ! grep -q 'after: 0' bodies/*.md || fail "a slug was left in a body"
  ! grep -qx '# A' bodies/41.md || fail "the title line is in the body"
  grep -qx '## Problem' bodies/41.md || fail "the body lost its sections"
}

# [agent-workflow-5f2d29]
test_existing_titles_are_skipped() {
  crm_fixture
  FAKE_ISSUES=$'7\tA' FAKE_LABELS=crm expect_pass crm_backlog
  expect_output "exists #7 A"
  ! grep -q '^\[label\]\[create\]' gh.log || fail "the label was created again"
  ! grep -qF '[--title][A]' gh.log || fail "A was filed again"
  [ "$(created)" -eq 2 ] || fail "expected 2 issues"
  grep -qx 'after: #7' bodies/41.md || fail "B does not depend on #7"$'\n'"$(cat bodies/41.md)"
  grep '^\[issue\]\[list\]' gh.log | grep -qF '[--state][all]' || fail "closed issues are not listed"
}

# [agent-workflow-6784a0]
test_template_repository_is_refused() {
  crm_fixture
  FAKE_TEMPLATE=true expect_fail crm_backlog
  expect_output "is a template repository"
  no_writes
}

# [agent-workflow-6784a0]
test_unreadable_template_flag_is_refused() {
  crm_fixture
  FAKE_VIEW_FAILS=1 expect_fail crm_backlog
  no_writes
}

# [agent-workflow-dcdfc6]
test_dry_run_only_reads() {
  crm_fixture
  FAKE_ISSUES=$'7\tA' expect_pass crm_backlog --dry-run
  expect_output "exists #7 A"
  expect_output "would file B"
  expect_output "  after: A"
  expect_output "would file C"
  expect_output "would create label crm"
  no_writes
}

# [agent-workflow-4be6a3]
test_forward_dependency_is_refused() {
  crm_fixture
  issue_file 01-a A 02-b
  expect_fail crm_backlog
  expect_output "01-a.md"
  no_writes
}

# [agent-workflow-4be6a3]
test_unknown_dependency_is_refused() {
  crm_fixture
  issue_file 02-b B 09-nope
  expect_fail crm_backlog
  expect_output "02-b.md"
  no_writes
}

# [agent-workflow-4be6a3]
test_file_without_a_title_is_refused() {
  crm_fixture
  printf 'A\n\n## Problem\n' > .claude/skills/crm-backlog/issues/01-a.md
  expect_fail crm_backlog
  expect_output "01-a.md"
  no_writes
}

# [agent-workflow-4c8a3b]
test_help_needs_no_gh() {
  crm_fixture
  rm fake-bin/gh
  expect_pass crm_backlog --help
  expect_output "usage: bin/crm-backlog"
  [ ! -s gh.log ] || fail "help called gh"
}

# [agent-workflow-4be6a3]
test_file_without_a_body_is_refused() {
  crm_fixture
  printf '# C\nafter: 01-a\n' > .claude/skills/crm-backlog/issues/03-c.md
  expect_fail crm_backlog
  expect_output "03-c.md"
  no_writes
}

# [agent-workflow-4be6a3]
test_badly_named_file_is_refused() {
  crm_fixture
  mv .claude/skills/crm-backlog/issues/03-c.md ".claude/skills/crm-backlog/issues/03 c.md"
  expect_fail crm_backlog
  expect_output "03 c.md"
  no_writes
}

# [agent-workflow-4be6a3]
test_after_without_a_space_is_refused() {
  crm_fixture
  printf '# B\nafter:01-a\n\n## Problem\n' > .claude/skills/crm-backlog/issues/02-b.md
  expect_fail crm_backlog
  expect_output "02-b.md"
  no_writes
}

# [agent-workflow-5f2d29]
test_titles_with_backslashes_are_matched() {
  crm_fixture
  issue_file 01-a 'A\b'
  FAKE_ISSUES=$'7\tA\\b' expect_pass crm_backlog
  expect_output 'exists #7 A\b'
  [ "$(created)" -eq 2 ] || fail "the existing issue was filed again"$'\n'"$(cat gh.log)"
}

test_unexpected_create_output_stops_the_run() {
  crm_fixture
  FAKE_CREATE_JUNK=1 expect_fail crm_backlog
  [ "$(created)" -eq 1 ] || fail "the run went on without an issue number"
}

test_unknown_argument_is_a_usage_error() {
  crm_fixture
  expect_fail crm_backlog --nope
  [ ! -s gh.log ] || fail "a usage error called gh"
}

test_titles_are_filed_verbatim() {
  crm_fixture
  issue_file 03-c 'Deals: "won" #1 & more' 01-a
  expect_pass crm_backlog
  grep -qF '[--title][Deals: "won" #1 & more]' gh.log || fail "title changed"$'\n'"$(cat gh.log)"
}

test_create_failure_stops_the_run() {
  crm_fixture
  FAKE_CREATE_FAILS=B expect_fail crm_backlog
  expect_output "filing 'B' failed"
  ! grep -qF '[--title][C]' gh.log || fail "the run went on after a failure"
}

# The shipped backlog: tickets, small enough and in order.

SHIPPED="$ROOT/.claude/skills/crm-backlog"

# [agent-workflow-322d7f]
test_issue_files_are_tickets() {
  local count=0 file titles='' title
  for file in "$SHIPPED"/issues/*.md; do
    count=$((count + 1))
    [[ "$(basename "$file")" =~ ^[0-9][0-9]-[a-z0-9-]+\.md$ ]] || fail "$file: not named NN-<slug>.md"
    title="$(head -n 1 "$file")"
    [[ "$title" == '# '* ]] || fail "$file: no title line"
    titles="$titles${title#'# '}"$'\n'
    for section in '## Problem' '## What we want' '## Scope'; do
      grep -qx "$section" "$file" || fail "$file: no $section"
    done
    ! grep -q $'\r' "$file" || fail "$file: CRLF line endings"
    ! grep -nE -- '(-R|--repo)[ =]+[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+' "$file" || fail "$file names a repository"
    ! grep -nE 'github\.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+' "$file" || fail "$file links a repository"
  done
  [ "$count" -ge 20 ] && [ "$count" -le 30 ] || fail "expected 20 to 30 issue files, found $count"
  [ -z "$(printf '%s' "$titles" | sort | uniq -d)" ] || fail "duplicate titles: $(printf '%s' "$titles" | sort | uniq -d)"
}

# [agent-workflow-dcdfc6]
test_shipped_backlog_dry_runs() {
  crm_fixture
  rm -rf .claude/skills/crm-backlog
  cp -R "$SHIPPED" .claude/skills/crm-backlog
  expect_pass crm_backlog --dry-run
  [ "$(grep -c '^would file ' <<< "$OUT")" -eq "$(find .claude/skills/crm-backlog/issues -name '*.md' | wc -l)" ] ||
    fail "not every shipped issue would be filed"$'\n'"$OUT"
  no_writes
}

# [agent-workflow-b95246]
test_skill_runs_the_script_and_stops() {
  local skill="$SHIPPED/SKILL.md"
  grep -qx 'name: crm-backlog' "$skill" || fail "no name front matter"
  grep -qF 'bin/crm-backlog' "$skill" || fail "the skill does not run bin/crm-backlog"
  grep -qF -- '--dry-run' "$skill" || fail "the skill does not offer --dry-run"
  grep -qiF 'not starting work' "$skill" || fail "the skill does not say filing is not starting work"
}
