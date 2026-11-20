# shellcheck shell=bash disable=SC2154
# bin/factory-graph, run from a copy in the test repository next to a stub
# bin/issue-trust that exits 4 for the issue numbers in $FAKE_UNTRUSTED
# (space-separated). The fake `gh` answers `issue list` by applying the
# script's own --jq filter to issues.json with the real jq, answers
# `issue view <n> --json state` from $FAKE_STATES (space-separated <n>:<STATE>
# pairs; an unknown number fails as gh does), and logs every call to gh.log.

graph() { bin/factory-graph "$@"; }

graph_fixture() {
  mkdir -p bin fake-bin
  cp "$BIN/factory-graph" "$BIN/repo" bin/
  cat > bin/issue-trust <<'STUB'
#!/usr/bin/env bash
for n in ${FAKE_UNTRUSTED:-}; do [ "$n" = "$1" ] && { echo "untrusted: @eve (none) cannot push to o/r" >&2; exit 4; }; done
echo "trusted: @ana (write)"
STUB
  cat > fake-bin/gh <<'GH'
#!/usr/bin/env bash
{ printf '[%s]' "$@"; echo; } >> gh.log
case "$1 $2" in
  "issue list")
    jq_filter=''
    while [ "$#" -gt 0 ]; do [ "$1" = --jq ] && jq_filter="$2"; shift; done
    jq -r "$jq_filter" issues.json ;;
  "issue view")
    for pair in ${FAKE_STATES:-}; do
      [ "${pair%%:*}" = "$3" ] && { echo "${pair#*:}"; exit 0; }
    done
    echo "GraphQL: Could not resolve to an issue or pull request with the number of $3. (repository.issue)" >&2
    exit 1 ;;
  *) echo "unexpected: gh $*" >&2; exit 1 ;;
esac
GH
  chmod +x bin/factory-graph bin/issue-trust fake-bin/gh
  PATH="$PWD/fake-bin:$PATH"
  : > gh.log
  git remote add origin git@github.com:o/r.git
  export FAKE_UNTRUSTED='' FAKE_STATES=''
}

# issues <json objects>: write issues.json from {"number","title","body","labels"} objects.
issues() { printf '[%s]\n' "$(IFS=,; echo "$*")" > issues.json; }
issue() { printf '{"number":%s,"title":"%s","body":"%s","labels":[%s]}' "$1" "$2" "${3:-}" "${4:-}"; }

# [agent-workflow-a8456b]
test_issue_without_open_dependencies_is_ready() {
  graph_fixture
  issues "$(issue 2 B 'Text\nafter: #9\n')" "$(issue 1 A 'No dependencies.')"
  FAKE_STATES='9:CLOSED' expect_pass graph crm
  [ "$OUT" = $'ready #1 A\nready #2 B' ] || fail "unexpected graph:"$'\n'"$OUT"
  grep -qF '[issue][list][-R][o/r][--label][crm][--state][open]' gh.log || fail "not listed from o/r:"$'\n'"$(cat gh.log)"
}

# [agent-workflow-e03701]
test_json_carries_the_records() {
  graph_fixture
  issues "$(issue 1 'A \"quoted\" title')" "$(issue 2 B 'after: #1')"
  expect_pass graph crm --json
  [ "$(jq -r '.[0].number, .[0].title, .[0].state' <<< "$OUT")" = $'1\nA "quoted" title\nready' ] || fail "first record:"$'\n'"$OUT"
  [ "$(jq -c '.[1] | [.state, .after]' <<< "$OUT")" = '["blocked",["#1"]]' ] || fail "second record:"$'\n'"$OUT"
  [ "$(jq -c '.[0].after' <<< "$OUT")" = '[]' ] || fail "a ready issue lists dependencies:"$'\n'"$OUT"
}

# [agent-workflow-4d6cae]
test_open_dependency_blocks() {
  graph_fixture
  issues "$(issue 1 A)" "$(issue 2 B 'after: #1')"
  expect_pass graph crm
  [ "$OUT" = $'ready #1 A\nblocked #2 B after #1' ] || fail "unexpected graph:"$'\n'"$OUT"
}

# [agent-workflow-4d6cae]
test_open_dependency_outside_the_label_blocks() {
  graph_fixture
  issues "$(issue 2 B 'after: #7')"
  FAKE_STATES='7:OPEN' expect_pass graph crm
  [ "$OUT" = 'blocked #2 B after #7' ] || fail "unexpected graph:"$'\n'"$OUT"
}

# [agent-workflow-dc0884]
test_missing_dependency_blocks() {
  graph_fixture
  issues "$(issue 2 B 'after: #99')"
  expect_pass graph crm
  [ "$OUT" = 'blocked #2 B after #99 (missing)' ] || fail "unexpected graph:"$'\n'"$OUT"
}

# [agent-workflow-55c314]
test_untrusted_issue() {
  graph_fixture
  issues "$(issue 3 C)"
  FAKE_UNTRUSTED=3 expect_pass graph crm
  [ "$OUT" = 'untrusted #3 C' ] || fail "unexpected graph:"$'\n'"$OUT"
}

# [agent-workflow-5ce1e6]
test_taken_issue() {
  graph_fixture
  issues "$(issue 4 D '' '{"name":"crm"},{"name":"in progress"}')"
  expect_pass graph crm
  [ "$OUT" = 'taken #4 D' ] || fail "unexpected graph:"$'\n'"$OUT"
}

# [agent-workflow-504c59]
test_cycle_is_reported() {
  graph_fixture
  issues "$(issue 5 E 'after: #6')" "$(issue 6 F 'after: #5')"
  expect_pass graph crm
  [ "$OUT" = $'cycle #5 E\ncycle #6 F' ] || fail "unexpected graph:"$'\n'"$OUT"
}

test_self_dependency_is_a_cycle() {
  graph_fixture
  issues "$(issue 5 E 'after: #5')"
  expect_pass graph crm
  [ "$OUT" = 'cycle #5 E' ] || fail "unexpected graph:"$'\n'"$OUT"
}

test_dependent_of_cycle_is_blocked() {
  graph_fixture
  issues "$(issue 5 E 'after: #6')" "$(issue 6 F 'after: #5')" "$(issue 7 G 'after: #5')"
  expect_pass graph crm
  [ "$(sed -n 3p <<< "$OUT")" = 'blocked #7 G after #5' ] || fail "unexpected graph:"$'\n'"$OUT"
}

test_only_exact_after_lines_count() {
  graph_fixture
  issues "$(issue 1 A)" "$(issue 2 B 'after: #1, #3\nAfter: #1\n  after: #1\nafter #1\nsee after: #1')" "$(issue 3 C 'after: #1  ')"
  expect_pass graph crm
  [ "$OUT" = $'ready #1 A\nready #2 B\nblocked #3 C after #1' ] || fail "unexpected graph:"$'\n'"$OUT"
}

test_untrusted_beats_taken_and_blocked() {
  graph_fixture
  issues "$(issue 1 A)" "$(issue 2 B 'after: #1' '{"name":"in progress"}')"
  FAKE_UNTRUSTED=2 expect_pass graph crm
  [ "$(sed -n 2p <<< "$OUT")" = 'untrusted #2 B' ] || fail "unexpected graph:"$'\n'"$OUT"
}

test_no_open_issues_prints_nothing() {
  graph_fixture
  issues
  expect_pass graph crm
  [ -z "$OUT" ] || fail "expected no output:"$'\n'"$OUT"
  expect_pass graph crm --json
  [ "$OUT" = '[]' ] || fail "expected an empty array:"$'\n'"$OUT"
}

test_graph_writes_nothing() {
  graph_fixture
  issues "$(issue 2 B 'after: #7')"
  FAKE_STATES='7:CLOSED' expect_pass graph crm
  # A call starts a line with "[<arg>]"; the multi-line --jq filter continues it.
  ! grep -E '^\[' gh.log | grep -vE '^\[issue\]\[(list|view)\]' || fail "the graph wrote to GitHub:"$'\n'"$(cat gh.log)"
}

test_usage_errors() {
  graph_fixture
  for args in '' 'a b' '--nope' 'crm --nope'; do
    # shellcheck disable=SC2086 # split the argument list on purpose
    if OUT="$(graph $args 2>&1)"; then fail "accepted: $args"; else status=$?; fi
    [ "$status" = 2 ] || fail "expected exit 2 for '$args', got $status"
    expect_output 'usage: bin/factory-graph'
  done
  [ ! -s gh.log ] || fail "a usage error called gh"
  PATH=/usr/bin:/bin expect_pass graph --help
  expect_output 'usage: bin/factory-graph'
}

# The web editor saves issue bodies with CRLF line endings.
test_after_lines_with_crlf_count() {
  graph_fixture
  issues "$(issue 1 A)" "$(issue 2 B 'Text\r\nafter: #1\r\nmore')"
  expect_pass graph crm
  [ "$OUT" = $'ready #1 A\nblocked #2 B after #1' ] || fail "unexpected graph:"$'\n'"$OUT"
}

