# shellcheck shell=bash disable=SC2154
# bin/scenario-id.sh against small fixture trees. The fixtures use the made-up
# capabilities "widgets" and "gadgets".

# id_spec <path under the root> <scenario heading>...
id_spec() {
  local file="$REPO/$1" heading
  mkdir -p "$(dirname "$file")"
  printf '## ADDED Requirements\n\n### Requirement: Something\nThe system SHALL do something.\n' > "$file"
  for heading in "${@:2}"; do
    printf '\n#### Scenario: %s\n- **WHEN** it happens\n- **THEN** it works\n' "$heading" >> "$file"
  done
}

# bytes <hex pairs...>: a SCENARIO_ID_SOURCE file holding exactly those bytes.
bytes() {
  local pair
  for pair in "$@"; do printf '%b' "\\x$pair"; done > "$REPO/.source"
  echo "$REPO/.source"
}

scenario_id() { (cd "$REPO" && "$BIN/scenario-id.sh" "$@"); }

# [spec-coverage-a3334a]
test_prints_fresh_ids() {
  id_spec openspec/specs/widgets/spec.md '[widgets-a00001] One'
  expect_pass scenario_id widgets 3
  [ "$(printf '%s\n' "$OUT" | wc -l | tr -d ' ')" = 3 ] || fail "expected 3 lines: $OUT"
  local id
  while IFS= read -r id; do
    [[ "$id" =~ ^widgets-[0-9a-f]{6}$ ]] || fail "not a hash ID: $id"
    [[ "$id" =~ [a-f] ]] || fail "all-digit hash: $id"
  done <<< "$OUT"
  [ "$(printf '%s\n' "$OUT" | sort -u | wc -l | tr -d ' ')" = 3 ] || fail "repeated ID: $OUT"
}

# [spec-coverage-a3334a]
test_skips_taken_and_all_digit_hashes() {
  id_spec openspec/specs/widgets/spec.md '[widgets-beefed] Taken'
  id_spec openspec/changes/7-abcdef-x/specs/widgets/spec.md '[widgets-c0ffee] Pending'
  SCENARIO_ID_SOURCE="$(bytes be ef ed c0 ff ee 12 34 56 fa ce d0)" expect_pass scenario_id widgets
  [ "$OUT" = widgets-faced0 ] || fail "expected widgets-faced0, got: $OUT"
}

# [spec-coverage-a3334a]
test_one_run_never_repeats_an_id() {
  id_spec openspec/specs/widgets/spec.md '[widgets-a00001] One'
  SCENARIO_ID_SOURCE="$(bytes ab cd ef ab cd ef fe dc ba)" expect_pass scenario_id widgets 2
  [ "$OUT" = $'widgets-abcdef\nwidgets-fedcba' ] || fail "expected abcdef then fedcba, got: $OUT"
}

# [spec-coverage-a3334a]
test_a_capability_only_in_an_active_change_works() {
  id_spec openspec/changes/7-abcdef-x/specs/gadgets/spec.md '[gadgets-abc123] New'
  expect_pass scenario_id gadgets
  [[ "$OUT" =~ ^gadgets-[0-9a-f]{6}$ ]] || fail "expected one gadgets ID, got: $OUT"
}

# [spec-coverage-bc5727]
test_unknown_capability_or_bad_count_fails() {
  id_spec openspec/specs/widgets/spec.md '[widgets-a00001] One'
  id_spec openspec/changes/archive/2026-01-01-7-abcdef-x/specs/gadgets/spec.md '[gadgets-a00001] Archived'
  local args
  for args in nope gadgets 'widgets 0' 'widgets x' '' 'widgets 1 2'; do
    # shellcheck disable=SC2086 # split the argument list on purpose
    expect_fail scenario_id $args
    expect_output 'usage: bin/scenario-id.sh'
    [[ "$OUT" != *widgets-* ]] || fail "printed an ID for '$args': $OUT"
  done
}

# [spec-coverage-a3334a]
test_out_of_candidates_fails() {
  id_spec openspec/specs/widgets/spec.md '[widgets-beefed] Taken'
  SCENARIO_ID_SOURCE="$(bytes be ef ed 12 34 56)" expect_fail scenario_id widgets
  expect_output 'could not find a free hash'
}

test_scenario_id_help() {
  expect_pass scenario_id --help
  expect_output 'usage: bin/scenario-id.sh'
}

# [spec-coverage-a3334a]
test_a_large_count_succeeds() {
  id_spec openspec/specs/widgets/spec.md '[widgets-a00001] One'
  expect_pass scenario_id widgets 300
  [ "$(printf '%s\n' "$OUT" | sort -u | wc -l | tr -d ' ')" = 300 ] || fail "expected 300 distinct IDs"
}
