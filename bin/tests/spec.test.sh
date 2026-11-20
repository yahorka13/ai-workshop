# shellcheck shell=bash disable=SC2154
# bin/spec against small fixture spec trees. The fixtures use the made-up
# capabilities "widgets" and "gadgets", so their text never cites a real
# scenario.

# capability <name> <purpose>: start openspec/specs/<name>/spec.md.
capability() {
  mkdir -p "$REPO/openspec/specs/$1"
  printf '# %s Specification\n\n## Purpose\n%s\n\n## Requirements\n' "$1" "$2" > "$REPO/openspec/specs/$1/spec.md"
}

# requirement <capability> <name> <text> <scenario heading>...
requirement() {
  local file="$REPO/openspec/specs/$1/spec.md" heading
  printf '\n### Requirement: %s\n%s\n' "$2" "$3" >> "$file"
  for heading in "${@:4}"; do
    printf '\n#### Scenario: %s\n- **WHEN** it happens\n- **THEN** it works\n' "$heading" >> "$file"
  done
}

# Two widgets requirements and one gadgets requirement.
fixture() {
  capability widgets 'Widgets spin and stop for the fixtures of the bin/spec tests.'
  requirement widgets 'Widgets spin' 'A widget SHALL spin when started.' '[widgets-a00001] Spin' '[widgets-a00002] Spin again'
  requirement widgets 'Widgets stop (on request)' 'A widget SHALL stop when "halt" is sent.' '[widgets-a00003] Stop'
  capability gadgets 'Gadgets blink for the fixtures of the bin/spec tests.'
  requirement gadgets 'Gadgets blink' 'A gadget SHALL blink when a widget spins.' '[gadgets-a00001] Blink'
}

spec() { (cd "$REPO" && "$BIN/spec" "$@"); }

commit_all() { git -C "$REPO" add -A && git -C "$REPO" commit -q --allow-empty -m "[1] $1"; }

# [spec-tools-ba6659]
test_find_by_scenario_id() {
  fixture
  expect_pass spec find widgets-a00003
  expect_output 'widgets'
  expect_output 'Widgets stop (on request)'
  expect_output "openspec/specs/widgets/spec.md:$(grep -n 'widgets-a00003' "$REPO/openspec/specs/widgets/spec.md" | cut -d: -f1)"
}

# [spec-tools-86cd51]
test_find_by_text() {
  fixture
  expect_pass spec find SPINS
  expect_output 'gadgets'
  expect_output 'Gadgets blink'
  expect_pass spec find 'spin'
  expect_output 'Widgets spin'
  expect_output 'Gadgets blink'
}

# [spec-tools-22d65d]
test_nothing_matches() {
  fixture
  expect_fail spec find 'no such thing'
  expect_output 'nothing matched'
}

test_find_matches_metacharacters_literally() {
  fixture
  expect_pass spec find '(on request)'
  expect_output 'Widgets stop (on request)'
  expect_pass spec find '"halt"'
  expect_output 'Widgets stop (on request)'
  expect_fail spec find '.*'
}

# [spec-tools-00bcf7]
test_show_by_scenario_id() {
  fixture
  expect_pass spec show widgets-a00002
  expect_output 'widgets: Widgets spin'
  expect_output 'A widget SHALL spin when started.'
  expect_output '[widgets-a00001] Spin'
  expect_output '[widgets-a00002] Spin again'
  [[ "$OUT" != *'Widgets stop'* ]] || fail 'printed another requirement'
}

# [spec-tools-076c1c]
test_show_by_name_in_any_case() {
  fixture
  expect_pass spec show 'gadgets BLINK'
  expect_output 'gadgets: Gadgets blink'
  expect_output '[gadgets-a00001] Blink'
}

# [spec-tools-64feb3]
test_an_ambiguous_name() {
  fixture
  expect_fail spec show 'widgets s'
  expect_output 'Widgets spin'
  expect_output 'Widgets stop (on request)'
}

test_show_lists_the_same_name_in_two_capabilities() {
  fixture
  requirement gadgets 'Widgets spin' 'A gadget SHALL let widgets spin.' '[gadgets-a00002] Let spin'
  expect_fail spec show 'widgets spin'
  expect_output 'widgets: Widgets spin'
  expect_output 'gadgets: Widgets spin'
  expect_pass spec find 'widgets spin'
  expect_output 'gadgets'
}

test_show_nothing_matches() {
  fixture
  expect_fail spec show 'nothing like it'
  expect_output 'nothing matched'
}

# [spec-tools-d7c38a]
test_show_prints_json() {
  fixture
  expect_pass spec show --json widgets-a00001
  jq -e '.capability == "widgets" and .name == "Widgets spin" and (.scenarios | length) == 2 and .scenarios[0].id == "widgets-a00001"' <<< "$OUT" > /dev/null \
    || fail "unexpected JSON: $OUT"
}

test_find_and_changed_print_json() {
  fixture
  commit_all base
  expect_pass spec find --json blink
  jq -e 'length == 1 and .[0].capability == "gadgets"' <<< "$OUT" > /dev/null || fail "unexpected JSON: $OUT"
  requirement gadgets 'Gadgets hum' 'A gadget SHALL hum.' '[gadgets-a00002] Hum'
  expect_pass spec changed --json --base HEAD
  jq -e '.added[0].name == "Gadgets hum" and .added[0].capability == "gadgets"' <<< "$OUT" > /dev/null || fail "unexpected JSON: $OUT"
}

# [spec-tools-f6c9fb]
test_help_outside_a_repository() {
  local dir sub
  dir="$(mktemp -d)"
  for sub in '' find show changed review; do
    # shellcheck disable=SC2086 # an empty subcommand is no argument
    OUT="$(cd "$dir" && "$BIN/spec" $sub --help 2>&1)" || fail "bin/spec $sub --help failed: $OUT"
    expect_output 'usage: bin/spec'
  done
  rm -rf "$dir"
}

test_bad_arguments_exit_2() {
  local status=0
  (cd "$REPO" && "$BIN/spec" frobnicate > /dev/null 2>&1) || status=$?
  [ "$status" -eq 2 ] || fail "expected exit 2, got $status"
  status=0
  (cd "$REPO" && "$BIN/spec" show > /dev/null 2>&1) || status=$?
  [ "$status" -eq 2 ] || fail "expected exit 2 for show without a query, got $status"
}

test_runs_from_a_subdirectory() {
  fixture
  mkdir -p "$REPO/services/x"
  OUT="$(cd "$REPO/services/x" && "$BIN/spec" show widgets-a00003 2>&1)" || fail "$OUT"
  expect_output 'Widgets stop (on request)'
}

# [spec-tools-9e1f9b]
test_changes_made_by_archiving() {
  fixture
  commit_all base
  requirement gadgets 'Gadgets hum' 'A gadget SHALL hum.' '[gadgets-a00002] Hum'
  sed -i.bak 's/A gadget SHALL blink when a widget spins./A gadget SHALL blink twice when a widget spins./' "$REPO/openspec/specs/gadgets/spec.md"
  rm "$REPO/openspec/specs/gadgets/spec.md.bak"
  commit_all archive
  expect_pass spec changed --base HEAD~1
  expect_output 'added     gadgets  Gadgets hum'
  expect_output 'modified  gadgets  Gadgets blink'
}

# [spec-tools-13bfa8]
test_a_moved_requirement() {
  fixture
  commit_all base
  capability sprockets 'Sprockets turn for the fixtures of the bin/spec tests.'
  requirement sprockets 'Gadgets blink' 'A gadget SHALL blink when a widget spins.' '[gadgets-a00001] Blink'
  rm -r "$REPO/openspec/specs/gadgets"
  expect_pass spec changed --base HEAD
  expect_output 'moved     gadgets -> sprockets  Gadgets blink'
  [[ "$OUT" != *'added'* && "$OUT" != *'removed'* ]] || fail "reported a move as added or removed: $OUT"
}

# [spec-tools-51d404]
test_a_changed_scenario() {
  fixture
  commit_all base
  sed -i.bak 's/^#### Scenario: \[widgets-a00002\] Spin again$/#### Scenario: [widgets-a00002] Spin once more/' "$REPO/openspec/specs/widgets/spec.md"
  rm "$REPO/openspec/specs/widgets/spec.md.bak"
  expect_pass spec changed --base HEAD
  expect_output 'modified  widgets  Widgets spin'
  expect_output 'widgets-a00002'
  [[ "$OUT" != *'widgets-a00001'* ]] || fail "named an unchanged scenario: $OUT"
}

# [spec-tools-bf9ba7]
test_no_change() {
  fixture
  commit_all base
  expect_pass spec changed --base HEAD
  expect_output 'specs did not change'
}

test_a_base_without_specs_reports_everything_as_added() {
  commit_all empty
  fixture
  expect_pass spec changed --base HEAD
  expect_output 'added     widgets  Widgets spin'
  expect_output 'added     gadgets  Gadgets blink'
}

test_a_spec_openspec_cannot_read_fails() {
  fixture
  commit_all base
  mkdir -p "$REPO/openspec/specs/broken"
  printf 'not a spec\n' > "$REPO/openspec/specs/broken/spec.md"
  expect_fail spec changed --base HEAD
  expect_output 'broken'
}

# [spec-tools-710d45]
test_an_active_change() {
  local change="$REPO/openspec/changes/7-abcdef-thing"
  fixture
  commit_all base
  mkdir -p "$change/specs/gadgets"
  printf 'schema: spec-driven\n' > "$change/.openspec.yaml"
  printf '# Proposal\n\n## Why\nThe fixtures need a change with one added and one removed requirement.\n\n## What Changes\n- Gadgets hum.\n' > "$change/proposal.md"
  printf '# Spec Delta\n\n## ADDED Requirements\n\n### Requirement: Gadgets hum\nA gadget SHALL hum.\n\n#### Scenario: [gadgets-a00002] Hum\n- **WHEN** on\n- **THEN** hum\n\n## REMOVED Requirements\n\n### Requirement: Gadgets blink\n**Reason**: Replaced.\n**Migration**: None.\n' > "$change/specs/gadgets/spec.md"
  expect_pass spec changed --base HEAD
  expect_output '7-abcdef-thing'
  expect_output 'ADDED    gadgets  Gadgets hum'
  expect_output 'REMOVED  gadgets  Gadgets blink'
}

# [spec-tools-6cdd2f]
test_review_of_a_cited_requirement() {
  fixture
  commit_all base
  sed -i.bak 's/A widget SHALL spin when started./A widget SHALL spin fast when started./' "$REPO/openspec/specs/widgets/spec.md"
  rm "$REPO/openspec/specs/widgets/spec.md.bak"
  mkdir -p "$REPO/services/e2e/tests"
  printf 'test("[widgets-a00001] spins", () => {});\n' > "$REPO/services/e2e/tests/widgets.spec.ts"
  expect_pass spec review --base HEAD
  expect_output 'widgets: Widgets spin (modified)'
  expect_output 'Widgets spin and stop for the fixtures of the bin/spec tests.'
  expect_output 'A widget SHALL spin fast when started.'
  expect_output '[widgets-a00001] Spin'
  expect_output 'cited by services/e2e/tests/widgets.spec.ts'
  expect_output '[widgets-a00002] Spin again'
  expect_output 'not covered'
  [[ "$OUT" != *'Gadgets blink'* ]] || fail "reviewed an unchanged requirement: $OUT"
}

# [spec-tools-caec5d]
test_review_of_an_excluded_scenario() {
  fixture
  commit_all base
  requirement gadgets 'Gadgets hum' 'A gadget SHALL hum.' '[gadgets-a00002] Hum'
  printf -- '- **NO E2E** not-built: no screen hums yet\n' >> "$REPO/openspec/specs/gadgets/spec.md"
  expect_pass spec review --base HEAD
  expect_output 'gadgets: Gadgets hum (added)'
  expect_output 'excluded: not-built: no screen hums yet'
}


test_a_heading_with_trailing_spaces_keeps_its_line() {
  fixture
  printf '\n### Requirement: Gadgets hum  \nA gadget SHALL hum.\n\n#### Scenario: [gadgets-a00002] Hum \n- **WHEN** on\n- **THEN** hum\n' >> "$REPO/openspec/specs/gadgets/spec.md"
  expect_pass spec show gadgets-a00002 --json
  [ "$(jq '.line' <<< "$OUT")" = "$(grep -n '^### Requirement: Gadgets hum' "$REPO/openspec/specs/gadgets/spec.md" | cut -d: -f1)" ] || fail "wrong line: $OUT"
}

test_two_requirements_of_one_name_keep_their_own_lines() {
  fixture
  requirement gadgets 'Gadgets blink' 'A gadget SHALL blink twice.' '[gadgets-a00002] Blink twice'
  expect_fail spec show 'Gadgets blink'
  local lines
  lines="$(grep -n '^### Requirement: Gadgets blink' "$REPO/openspec/specs/gadgets/spec.md" | cut -d: -f1 | tr '\n' ' ')"
  for line in $lines; do
    expect_output "openspec/specs/gadgets/spec.md:$line"
  done
}
