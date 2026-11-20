# shellcheck shell=bash disable=SC2154
# bin/check-spec-coverage.sh against small fixture trees. The fixtures use the
# made-up capabilities "widgets" and "gadgets", so their text never cites a
# real scenario.

# spec_file <path under the root> <capability folder> <scenario heading>...
spec_file() {
  local file="$REPO/$1" heading
  mkdir -p "$(dirname "$file")"
  printf '# %s Specification\n\n## Requirements\n\n### Requirement: Something\nThe system SHALL do something.\n' "$2" > "$file"
  for heading in "${@:3}"; do
    printf '\n#### Scenario: %s\n- **WHEN** it happens\n- **THEN** it works\n' "$heading" >> "$file"
  done
}

# cite <path under the root> <text>
cite() {
  mkdir -p "$(dirname "$REPO/$1")"
  printf '%s\n' "$2" >> "$REPO/$1"
}

# exclude <id> <line>...: add the lines to the end of that scenario, in the
# main spec that holds it, as an exclusion is written.
exclude() {
  local id="$1" file
  shift
  file="$(grep -rlF -- "#### Scenario: [$id]" "$REPO/openspec/specs")"
  LINES="$(printf '%s\n' "$@")" awk -v id="$id" '
    function flush() { if (inside) print ENVIRON["LINES"]; inside = 0 }
    /^#/ { flush() }
    /^$/ && inside { flush() }
    { print }
    index($0, "#### Scenario: [" id "]") == 1 { inside = 1 }
    END { flush() }
  ' "$file" > "$file.new" && mv "$file.new" "$file"
}

# unexclude: remove every exclusion from the widgets spec.
unexclude() {
  sed -i.bak '/NO E2E/d' "$REPO/openspec/specs/widgets/spec.md" && rm "$REPO/openspec/specs/widgets/spec.md.bak"
}

reset_tree() { rm -rf "${REPO:?}/openspec" "${REPO:?}/services" "${REPO:?}/bin"; }

coverage() { "$BIN/check-spec-coverage.sh" "$REPO"; }

# Two widgets scenarios, both cited by end-to-end tests: a passing tree.
covered_tree() {
  spec_file openspec/specs/widgets/spec.md widgets '[widgets-a00001] One' '[widgets-a00002] Two'
  cite services/e2e/tests/widgets.spec.ts 'test("[widgets-a00001] one", () => {});'
  cite bin/tests/widgets.test.sh '# [widgets-a00002]'
}

test_clean_tree_prints_a_summary() {
  covered_tree
  spec_file openspec/specs/gadgets/spec.md gadgets '[gadgets-a00001] Rule'
  cite services/backend/tests/gadgets.test.ts 'test("[gadgets-a00001] rule", () => {});'
  exclude gadgets-a00001 '- **NO E2E** internal-rule: enforced by services/backend/tests/gadgets.test.ts'
  expect_pass coverage
  expect_output '3 scenarios: 2 cited, 1 excluded'
}

# [spec-coverage-10e800]
test_malformed_ids_fail() {
  local heading
  for heading in 'No ID at all' '[gadgets-a00001] Another capability' 'ID at the end [widgets-a00003]' '[widgets-0] Zero' '[widgets-3] A number' '[widgets-x] Not a hash'; do
    reset_tree
    covered_tree
    printf '\n#### Scenario: %s\n- **WHEN** a\n- **THEN** b\n' "$heading" >> "$REPO/openspec/specs/widgets/spec.md"
    expect_fail coverage
    expect_output 'openspec/specs/widgets/spec.md'
    expect_output "$heading"
  done
}

# [spec-coverage-bdaecf]
test_duplicate_ids_fail() {
  covered_tree
  spec_file openspec/specs/widgets/other.md widgets '[widgets-a00001] Copy'
  spec_file openspec/specs/widgets/spec.md widgets '[widgets-a00001] One' '[widgets-a00002] Two' '[widgets-a00002] Again'
  expect_fail coverage
  expect_output 'duplicate scenario ID: widgets-a00002'
}

# [spec-coverage-1260aa]
test_active_change_deltas_are_checked() {
  covered_tree
  spec_file openspec/changes/7-abcdef-thing/specs/widgets/spec.md widgets 'Unnumbered in a change'
  expect_fail coverage
  expect_output 'openspec/changes/7-abcdef-thing/specs/widgets/spec.md'
  expect_output 'Unnumbered in a change'
}

# [spec-coverage-1260aa]
test_archived_changes_are_not_read() {
  covered_tree
  spec_file openspec/changes/archive/2026-01-01-7-abcdef-thing/specs/widgets/spec.md widgets 'Old unnumbered'
  expect_pass coverage
}

# [spec-coverage-e71ee5]
test_an_uncovered_scenario_fails_with_the_fixes() {
  covered_tree
  spec_file openspec/specs/widgets/spec.md widgets '[widgets-a00001] One' '[widgets-a00002] Two' '[widgets-a00003] Three'
  expect_fail coverage
  expect_output 'not covered: widgets-a00003'
  expect_output 'services/e2e/tests/'
  expect_output 'bin/tests/'
  expect_output '- **NO E2E** <category>: <reason>'
}

# [spec-coverage-e71ee5]
test_removing_the_only_test_fails() {
  covered_tree
  expect_pass coverage
  rm "$REPO/services/e2e/tests/widgets.spec.ts"
  expect_fail coverage
  expect_output 'not covered: widgets-a00001'
}

# [spec-coverage-4d6888]
test_service_test_citations_do_not_count() {
  covered_tree
  spec_file openspec/specs/widgets/spec.md widgets '[widgets-a00001] One' '[widgets-a00002] Two' '[widgets-a00003] Three'
  cite services/ui/tests/unit/widgets.test.ts 'test("[widgets-a00003] three", () => {});'
  expect_fail coverage
  expect_output 'not covered: widgets-a00003'
}

# [spec-coverage-5e9cfb]
test_a_compressed_citation_covers_its_first_id() {
  spec_file openspec/specs/widgets/spec.md widgets '[widgets-a00001] One' '[widgets-a00002] Two'
  cite bin/tests/widgets.test.sh '# [widgets-a00001, 2]'
  expect_fail coverage
  expect_output 'not covered: widgets-a00002'
  [[ "$OUT" != *'not covered: widgets-a00001'* ]] || fail 'widgets-a00001 was cited'
}

# [spec-coverage-b28b5c]
test_exclusion_needs_a_category_and_a_reason() {
  local line
  for line in '- **NO E2E**' '- **NO E2E** not-built' '- **NO E2E** not-built:' '- **NO E2E** someday: because reasons'; do
    reset_tree
    covered_tree
    spec_file openspec/specs/widgets/spec.md widgets '[widgets-a00001] One' '[widgets-a00002] Two' '[widgets-a00003] Three'
    exclude widgets-a00003 "$line"
    expect_fail coverage
    expect_output 'openspec/specs/widgets/spec.md:19:'
    expect_output 'internal-rule, not-built, external'
  done
}

# [spec-coverage-b28b5c]
test_each_category_is_accepted() {
  local category
  for category in not-built external; do
    reset_tree
    covered_tree
    spec_file openspec/specs/widgets/spec.md widgets '[widgets-a00001] One' '[widgets-a00002] Two' '[widgets-a00003] Three'
    exclude widgets-a00003 "- **NO E2E** $category: no screen shows widgets yet"
    expect_pass coverage
  done
}


# [spec-coverage-3c7c6b]
test_a_stray_or_repeated_exclusion_fails() {
  covered_tree
  spec_file openspec/specs/widgets/spec.md widgets '[widgets-a00001] One' '[widgets-a00002] Two' '[widgets-a00003] Three'
  # Under the requirement's text, before any scenario.
  sed -i.bak 's/^The system SHALL do something.$/&\n- **NO E2E** not-built: no scenario here/' "$REPO/openspec/specs/widgets/spec.md"
  rm "$REPO/openspec/specs/widgets/spec.md.bak"
  exclude widgets-a00003 '- **NO E2E** not-built: later'
  expect_fail coverage
  expect_output 'an exclusion belongs inside a scenario'
  unexclude
  exclude widgets-a00003 '- **NO E2E** not-built: later' '- **NO E2E** external: twice'
  expect_fail coverage
  expect_output 'widgets-a00003 is excluded twice'
}

# [spec-coverage-bd4e42]
test_a_cited_scenario_leaves_the_exclusions() {
  covered_tree
  exclude widgets-a00001 '- **NO E2E** not-built: written before the test'
  expect_fail coverage
  expect_output 'widgets-a00001'
  expect_output 'remove'
}

# [spec-coverage-195ea5]
test_an_internal_rule_names_an_existing_test() {
  covered_tree
  spec_file openspec/specs/widgets/spec.md widgets '[widgets-a00001] One' '[widgets-a00002] Two' '[widgets-a00003] Three'
  exclude widgets-a00003 '- **NO E2E** internal-rule: the database rejects it'
  expect_fail coverage
  expect_output 'openspec/specs/widgets/spec.md:'
  unexclude
  exclude widgets-a00003 '- **NO E2E** internal-rule: covered by services/backend/tests/missing.test.ts'
  expect_fail coverage
  expect_output 'services/backend/tests/missing.test.ts'
  cite services/backend/tests/missing.test.ts 'test("[widgets-a00003] rule", () => {});'
  expect_pass coverage
  unexclude
  exclude widgets-a00003 '- **NO E2E** internal-rule: rendered rules checked by infrastructure/modules/x/tests/x.tftest.hcl'
  expect_fail coverage
  cite infrastructure/modules/x/tests/x.tftest.hcl 'run "widgets" {}'
  expect_pass coverage
  # A repository Claude Code plugin's own tests.
  unexclude
  exclude widgets-a00003 '- **NO E2E** internal-rule: covered by .claude/plugins/x/tests/x.test.ts'
  expect_fail coverage
  expect_output '.claude/plugins/x/tests/x.test.ts'
  cite .claude/plugins/x/tests/x.test.ts 'test("[widgets-a00003] rule", async () => {})'
  expect_pass coverage
}

# [spec-coverage-e55e80]
test_hash_ids_are_accepted() {
  spec_file openspec/specs/widgets/spec.md widgets '[widgets-a00001] One' '[widgets-3f9c1a] Hash' '[widgets-beefed] Letters'
  cite services/e2e/tests/widgets.spec.ts 'test("[widgets-a00001] one", () => {});'
  cite services/e2e/tests/widgets.spec.ts 'test("[widgets-3f9c1a] hash", () => {});'
  cite bin/tests/widgets.test.sh '# [widgets-beefed]'
  expect_pass coverage
  expect_output '3 scenarios: 3 cited, 0 excluded'
}

# [spec-coverage-e55e80]
test_malformed_hashes_fail() {
  # A hash needs a letter, so it never reads like a number.
  local heading
  for heading in '[widgets-123456] All digits' '[widgets-3f9c1] Five' '[widgets-3f9c1ab] Seven' '[widgets-3F9C1A] Upper case' '[widgets-03f9c1a] Leading zero'; do
    reset_tree
    covered_tree
    printf '\n#### Scenario: %s\n- **WHEN** a\n- **THEN** b\n' "$heading" >> "$REPO/openspec/specs/widgets/spec.md"
    expect_fail coverage
    expect_output 'openspec/specs/widgets/spec.md'
    expect_output "$heading"
  done
}

# [spec-coverage-c9cec7]
test_hash_citations_count() {
  spec_file openspec/specs/widgets/spec.md widgets '[widgets-3f9c1a] Hash' '[widgets-beefed] Letters' '[widgets-a00002] Two'
  cite services/e2e/tests/widgets.spec.ts 'test("[widgets-3f9c1a] hash", () => {});'
  cite bin/tests/widgets.test.sh '# [widgets-beefed, widgets-a00002]'
  expect_fail coverage
  expect_output 'not covered: widgets-a00002'
  [[ "$OUT" != *'not covered: widgets-3f9c1a'* ]] || fail 'widgets-3f9c1a was cited'
  [[ "$OUT" != *'not covered: widgets-beefed'* ]] || fail 'widgets-beefed was cited'
  [[ "$OUT" != *'must start with'* ]] || fail "hash IDs were read as malformed: $OUT"
}

# [spec-coverage-c9cec7]
test_hash_exclusion_is_accepted() {
  covered_tree
  spec_file openspec/specs/widgets/spec.md widgets '[widgets-a00001] One' '[widgets-a00002] Two' '[widgets-beefed] Later'
  exclude widgets-beefed '- **NO E2E** not-built: no screen shows it yet'
  expect_pass coverage
}


# base_commit: commit the tree and print its SHA.
base_commit() {
  git -C "$REPO" add -A
  git -C "$REPO" commit -q -m '[1] Base'
  git -C "$REPO" rev-parse HEAD
}





test_spec_coverage_help_and_bad_arguments() {
  expect_pass "$BIN/check-spec-coverage.sh" --help
  expect_output 'NO E2E'
  expect_output 'internal-rule'
  expect_fail "$BIN/check-spec-coverage.sh" "$REPO" extra
  expect_fail "$BIN/check-spec-coverage.sh" "$REPO/does-not-exist"
  expect_fail "$BIN/check-spec-coverage.sh" --base HEAD
  expect_pass "$BIN/check-spec-coverage.sh" --help
  expect_output 'bin/scenario-id.sh'
}

# [spec-coverage-b73968]
test_a_change_moves_a_scenario() {
  covered_tree
  spec_file openspec/changes/7-abcdef-move/specs/gadgets/spec.md gadgets '[widgets-a00001] Moved here'
  expect_pass coverage
}

# [spec-coverage-fae502]
test_a_change_borrows_a_prefix_for_a_new_scenario() {
  covered_tree
  spec_file openspec/changes/7-abcdef-move/specs/gadgets/spec.md gadgets '[widgets-a00009] Not in the main specs'
  expect_fail coverage
  expect_output 'openspec/changes/7-abcdef-move/specs/gadgets/spec.md'
  expect_output '[widgets-a00009] Not in the main specs'
  expect_output 'bin/scenario-id.sh gadgets'
}


# [spec-coverage-ecd608]
test_a_live_capability_prefix_is_accepted() {
  covered_tree
  spec_file openspec/specs/gadgets/spec.md gadgets '[widgets-a00007] Moved from widgets'
  cite bin/tests/widgets.test.sh '# [widgets-a00007]'
  expect_pass coverage
}

# [spec-coverage-60707c]
test_an_unknown_prefix_fails() {
  covered_tree
  spec_file openspec/specs/gadgets/spec.md gadgets '[nowhere-a00003] From nowhere'
  cite bin/tests/nowhere.test.sh '# [nowhere-a00003]'
  expect_fail coverage
  expect_output 'openspec/specs/gadgets/spec.md'
  expect_output '[nowhere-a00003] From nowhere'
}

# [spec-coverage-bdaecf]
test_duplicate_ids_across_capabilities_fail() {
  covered_tree
  spec_file openspec/specs/gadgets/spec.md gadgets '[widgets-a00001] Copied'
  expect_fail coverage
  expect_output 'duplicate scenario ID: widgets-a00001'
}

test_a_numeric_scenario_id_fails() {
  covered_tree
  printf '\n#### Scenario: [widgets-12] Numbered\n- **WHEN** a\n- **THEN** b\n' >> "$REPO/openspec/specs/widgets/spec.md"
  expect_fail coverage
  expect_output 'openspec/specs/widgets/spec.md'
  expect_output '[widgets-<hash>]'
  reset_tree
  covered_tree
  spec_file openspec/changes/7-abcdef-x/specs/widgets/spec.md widgets '[widgets-12] Numbered'
  expect_fail coverage
  expect_output 'openspec/changes/7-abcdef-x/specs/widgets/spec.md'
  expect_output '[widgets-<hash>]'
}

test_coverage_without_an_e2e_service_counts_bin_tests() {
  spec_file openspec/specs/widgets/spec.md widgets '[widgets-b0000a] Cited' '[widgets-b0000b] Uncited'
  cite bin/tests/widgets.test.sh '# [widgets-b0000a]'
  [ ! -d "$REPO/services/e2e" ] || fail 'the fixture has an e2e service'
  expect_fail coverage
  expect_output 'not covered: widgets-b0000b'
  cite bin/tests/more.test.sh '# [widgets-b0000b]'
  expect_pass coverage
}
