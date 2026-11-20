# shellcheck shell=bash disable=SC2154
# bin/check-spec-obligations.sh against small fixture spec trees with the
# made-up capabilities "widgets" and "gadgets".

# ob_capability <name>: start openspec/specs/<name>/spec.md.
ob_capability() {
  mkdir -p "$REPO/openspec/specs/$1"
  printf '# %s Specification\n\n## Purpose\nThe %s of the fixtures for the obligation check tests.\n\n## Requirements\n' "$1" "$1" > "$REPO/openspec/specs/$1/spec.md"
}

# ob_requirement <capability> <name> <text> <scenario id>
ob_requirement() {
  printf '\n### Requirement: %s\n%s\n\n#### Scenario: [%s] It holds\n- **WHEN** it happens\n- **THEN** the widget SHALL work\n' "$2" "$3" "$4" >> "$REPO/openspec/specs/$1/spec.md"
}

# ob_change <change> <capability> <delta body>: an active change with one delta.
ob_change() {
  local dir="$REPO/openspec/changes/$1"
  mkdir -p "$dir/specs/$2"
  printf 'schema: spec-driven\n' > "$dir/.openspec.yaml"
  printf '# Proposal\n\n## Why\nThe fixtures need an active change for the obligation check tests.\n\n## What Changes\n- Something.\n' > "$dir/proposal.md"
  printf '# Spec Delta\n\n%s\n' "$3" > "$dir/specs/$2/spec.md"
}

# A tree with one bundled widgets requirement, already in the main specs.
ob_fixture() {
  ob_capability widgets
  ob_requirement widgets 'Widgets spin' 'A widget SHALL spin.' widgets-a00001
  ob_requirement widgets 'Widgets stop' 'A widget SHALL stop. It MUST NOT smoke.' widgets-a00002
  ob_capability gadgets
  ob_requirement gadgets 'Gadgets blink' 'A gadget SHALL blink.' gadgets-a00001
}

ob_commit() { git -C "$REPO" add -A && git -C "$REPO" commit -q --allow-empty --no-verify -m "[1] $1"; }

reset_change() { rm -rf "${REPO:?}/openspec"; }

obligations() { (cd "$REPO" && "$BIN/check-spec-obligations.sh" "$@"); }

test_the_fixture_passes() {
  ob_fixture
  expect_pass obligations
}

# [spec-tools-26dd7c]
test_two_obligations_are_bundled() {
  ob_fixture
  ob_change 7-abcdef-thing gadgets $'## ADDED Requirements\n\n### Requirement: Gadgets stop\nA gadget SHALL stop. It MUST NOT smoke.\n\n#### Scenario: [gadgets-a00002] Stop\n- **WHEN** off\n- **THEN** stop'
  expect_fail obligations
  expect_output 'Gadgets stop has 2 obligations'
}

test_bundled_requirements_already_in_the_specs_pass_and_are_counted() {
  ob_fixture
  expect_pass obligations
  expect_output 'no new bundled requirement; 1 remain in openspec/specs/'
}

# [spec-tools-84c073]
test_keywords_in_scenarios_do_not_count() {
  ob_fixture
  # Every fixture scenario says SHALL; only "Widgets stop" is bundled.
  expect_pass obligations
}

# [spec-tools-41cd27]
test_quoted_keywords_do_not_count() {
  ob_fixture
  # shellcheck disable=SC2016 # backticks are spec text
  ob_requirement gadgets 'Gadgets name the keywords' 'A gadget SHALL print `SHALL` and "MUST NOT" when asked.' gadgets-a00002
  expect_pass obligations
}

# [spec-tools-b33e00]
test_a_change_adds_a_bundled_requirement() {
  ob_fixture
  ob_change 7-abcdef-thing gadgets $'## ADDED Requirements\n\n### Requirement: Gadgets hum\nA gadget SHALL hum. It SHALL hum quietly.\n\n#### Scenario: [gadgets-a00002] Hum\n- **WHEN** on\n- **THEN** hum'
  expect_fail obligations
  expect_output 'openspec/changes/7-abcdef-thing/specs/gadgets/spec.md:5: Gadgets hum has 2 obligations'
  expect_output 'split it into one requirement per SHALL or MUST'
}

test_a_change_modifies_a_requirement_into_a_bundle() {
  ob_fixture
  ob_change 7-abcdef-thing gadgets $'## MODIFIED Requirements\n\n### Requirement: Gadgets blink\nA gadget SHALL blink. It MUST blink twice.\n\n#### Scenario: [gadgets-a00001] It holds\n- **WHEN** it happens\n- **THEN** the widget SHALL work'
  expect_fail obligations
  expect_output 'Gadgets blink has 2 obligations'
}

# [spec-tools-3828ea]
test_single_obligations_pass() {
  ob_fixture
  ob_change 7-abcdef-thing gadgets $'## ADDED Requirements\n\n### Requirement: Gadgets hum\nA gadget SHALL hum.\n\n#### Scenario: [gadgets-a00002] Hum\n- **WHEN** on\n- **THEN** hum'
  expect_pass obligations
}

# [spec-tools-e6451d]
test_a_moved_bundled_requirement_is_not_reported() {
  ob_fixture
  ob_change 7-abcdef-move gadgets $'## ADDED Requirements\n\n### Requirement: Widgets stop\nA widget SHALL stop. It MUST NOT smoke.\n\n#### Scenario: [widgets-a00002] It holds\n- **WHEN** it happens\n- **THEN** the widget SHALL work'
  mkdir -p "$REPO/openspec/changes/7-abcdef-move/specs/widgets"
  printf '# Spec Delta\n\n## REMOVED Requirements\n\n### Requirement: Widgets stop\n**Reason**: Moved.\n**Migration**: gadgets.\n' > "$REPO/openspec/changes/7-abcdef-move/specs/widgets/spec.md"
  expect_pass obligations
}

# [spec-tools-982d5e]
test_a_bundled_requirement_arrives_by_archive() {
  ob_fixture
  ob_commit base
  ob_requirement gadgets 'Gadgets hum' 'A gadget SHALL hum. It SHALL hum quietly.' gadgets-a00002
  sed -i.bak 's/A widget SHALL stop. It MUST NOT smoke./A widget SHALL stop without smoke./' "$REPO/openspec/specs/widgets/spec.md"
  rm "$REPO/openspec/specs/widgets/spec.md.bak"
  expect_fail obligations --base HEAD
  expect_output "openspec/specs/gadgets/spec.md:$(grep -n 'Gadgets hum' "$REPO/openspec/specs/gadgets/spec.md" | cut -d: -f1): Gadgets hum has 2 obligations"
}

test_a_scenario_edit_under_a_bundled_requirement_is_not_reported() {
  ob_fixture
  ob_commit base
  sed -i.bak 's/- \*\*WHEN\*\* it happens/- **WHEN** it happens today/' "$REPO/openspec/specs/widgets/spec.md"
  rm "$REPO/openspec/specs/widgets/spec.md.bak"
  expect_pass obligations --base HEAD
}

# ob_moved_tree: the bundled widgets requirement moves, unchanged, to sprockets.
ob_moved_tree() {
  ob_fixture
  ob_commit base
  ob_capability sprockets
  ob_requirement sprockets 'Widgets stop' 'A widget SHALL stop. It MUST NOT smoke.' widgets-a00002
  python3 - "$REPO/openspec/specs/widgets/spec.md" <<'PY'
import sys
p = sys.argv[1]; s = open(p).read()
i = s.index("\n### Requirement: Widgets stop")
open(p, "w").write(s[:i] + "\n")
PY
}

test_a_moved_bundled_requirement_passes_against_the_base() {
  ob_moved_tree
  expect_pass obligations --base HEAD
}

test_help_and_bad_arguments() {
  local status=0
  expect_pass "$BIN/check-spec-obligations.sh" --help
  expect_output 'usage: bin/check-spec-obligations.sh'
  "$BIN/check-spec-obligations.sh" --frobnicate > /dev/null 2>&1 || status=$?
  [ "$status" -eq 2 ] || fail "expected exit 2, got $status"
}

# [spec-tools-91e7a8]
test_spec_instructions_say_one_obligation() {
  grep -qF 'One obligation per requirement - a second SHALL or MUST is a second requirement' "$ROOT/openspec/config.yaml" \
    || fail 'openspec/config.yaml has no one-obligation rule'
  grep -qF 'one obligation, one SHALL or MUST; a second is a second requirement' "$ROOT/openspec/schemas/factory/templates/spec.md" \
    || fail 'the spec template has no one-obligation rule'
}

test_a_tree_without_specs_passes() {
  expect_pass obligations
}


# An unpaired quote or backtick hides nothing past its sentence.
test_a_stray_quote_does_not_hide_a_second_obligation() {
  local text
  # shellcheck disable=SC2016 # backticks are spec text
  for text in 'The label SHALL be 3" wide. It MUST be 2" tall.' 'The prompt SHALL end with ` and the output MUST end with `. Then it SHALL stop.'; do
    reset_change
    ob_fixture
    ob_change 7-abcdef-thing gadgets "## ADDED Requirements

### Requirement: Gadgets label
$text

#### Scenario: [gadgets-a00002] Label
- **WHEN** on
- **THEN** label"
    expect_fail obligations
    expect_output 'Gadgets label has'
  done
}
