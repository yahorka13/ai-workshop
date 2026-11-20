# shellcheck shell=bash disable=SC2154
# bin/proof-markdown: the PR's ## Proof body from a commit's proof files, linked
# into the repository bin/repo names.

proof_markdown() { "$BIN/proof-markdown" "$@"; }

# main_at_start: origin/main at the current commit, unless a test set it.
main_at_start() {
  git -C "$REPO" rev-parse -q --verify refs/remotes/origin/main > /dev/null \
    || git -C "$REPO" update-ref refs/remotes/origin/main HEAD
}

# A widgets scenario in the main specs and a screenshot and video of its test.
commit_proof() {
  local dir="$REPO/$1"
  git -C "$REPO" remote add origin git@github.com:owner/repo.git 2> /dev/null || true
  main_at_start
  mkdir -p "$dir" "$REPO/openspec/specs/widgets"
  cat > "$REPO/openspec/specs/widgets/spec.md" <<'SPEC'
# widgets Specification

## Requirements

### Requirement: Unknown widgets
The system SHALL say so.

#### Scenario: [widgets-3a4b5c] Unknown widget shows not-found
- **WHEN** a browser opens an unknown widget
- **THEN** the not-found screen is shown
- **AND** it links home

#### Scenario: [widgets-4d5e6f] Another
- **WHEN** something else
- **THEN** not this
SPEC
  printf 'png' > "$dir/widgets-3a4b5c-unknown-widget-shows-not-found.png"
  printf 'webm' > "$dir/widgets-3a4b5c-unknown-widget-shows-not-found.webm"
  git -C "$REPO" add -A
  git -C "$REPO" commit -q -m '[7][abcdef] Add proof'
}

# [spec-coverage-acc3ac]
test_spec_coverage_acc3ac_proof_files_become_permalinks() {
  commit_proof openspec/changes/7-abcdef-thing/proof
  local sha base
  sha="$(git -C "$REPO" rev-parse HEAD)"
  base="https://github.com/owner/repo/blob/$sha"
  expect_pass proof_markdown HEAD
  expect_output '## Proof'
  expect_output "![widgets-3a4b5c-unknown-widget-shows-not-found]($base/openspec/changes/7-abcdef-thing/proof/widgets-3a4b5c-unknown-widget-shows-not-found.png?raw=true)"
  expect_output "[Video]($base/openspec/changes/7-abcdef-thing/proof/widgets-3a4b5c-unknown-widget-shows-not-found.webm?raw=true)"
}

# [spec-coverage-d54754]
test_spec_coverage_d54754_a_proof_is_captioned() {
  commit_proof openspec/changes/7-abcdef-thing/proof
  expect_pass proof_markdown HEAD
  expect_output '### [widgets-3a4b5c] Unknown widget shows not-found'
  expect_output 'Expected: **THEN** the not-found screen is shown **AND** it links home'
  [[ "$OUT" != *'not this'* ]] || fail "another scenario's outcome leaked into the caption"
  # The heading comes first, then the screenshot and the video.
  [[ "$OUT" == *'### [widgets-3a4b5c]'*'![widgets-3a4b5c'*'[Video]'* ]] || fail "caption, image and video out of order: $OUT"
}

# [spec-coverage-1028ae] [spec-coverage-83cedb]
test_spec_coverage_1028ae_a_scenario_still_in_its_change_is_found() {
  git -C "$REPO" remote add origin git@github.com:owner/repo.git
  main_at_start
  mkdir -p "$REPO/openspec/changes/7-abcdef-thing/specs/widgets" "$REPO/openspec/changes/7-abcdef-thing/proof"
  printf '## ADDED Requirements\n\n### Requirement: X\nThe system SHALL.\n\n#### Scenario: [widgets-9a8b7c] Fresh one\n- **WHEN** a\n- **THEN** the fresh screen\n' \
    > "$REPO/openspec/changes/7-abcdef-thing/specs/widgets/spec.md"
  printf 'png' > "$REPO/openspec/changes/7-abcdef-thing/proof/widgets-9a8b7c-fresh-one.png"
  printf 'png' > "$REPO/openspec/changes/7-abcdef-thing/proof/overview.png"
  git -C "$REPO" add -A
  git -C "$REPO" commit -q -m '[7][abcdef] Add proof'
  expect_pass proof_markdown HEAD
  expect_output '### [widgets-9a8b7c] Fresh one'
  expect_output 'Expected: **THEN** the fresh screen'
  # [spec-coverage-83cedb] A name that is no scenario keeps its name.
  expect_output '### overview'
}

# [spec-coverage-7eef0b]
test_spec_coverage_7eef0b_archived_proof_is_found() {
  commit_proof openspec/changes/7-abcdef-thing/proof
  mkdir -p "$REPO/openspec/changes/archive"
  git -C "$REPO" mv openspec/changes/7-abcdef-thing openspec/changes/archive/2026-11-17-7-abcdef-thing
  git -C "$REPO" commit -q -m '[7][abcdef] Archive 7-abcdef-thing'
  local sha
  sha="$(git -C "$REPO" rev-parse HEAD)"
  expect_pass proof_markdown "$sha"
  expect_output "blob/$sha/openspec/changes/archive/2026-11-17-7-abcdef-thing/proof/widgets-3a4b5c-unknown-widget-shows-not-found.png?raw=true"
}

# [spec-coverage-0c1f35]
test_spec_coverage_0c1f35_no_proof_files() {
  git -C "$REPO" remote add origin git@github.com:owner/repo.git
  main_at_start
  expect_fail proof_markdown HEAD
  expect_output 'bin/e2e --proof'
}

test_proof_markdown_usage() {
  expect_pass proof_markdown --help
  expect_output 'permalink'
  expect_fail proof_markdown
  expect_fail proof_markdown no-such-ref
  expect_output 'no-such-ref'
}

# hash_proof <spec heading> <THEN line> <proof file name>: a main spec with one
# scenario and a committed screenshot named after a test.
hash_proof() {
  local cap="${1#\[}" dir="$REPO/openspec/changes/7-abcdef-thing/proof"
  cap="${cap%%]*}"
  cap="${cap%-*}"
  git -C "$REPO" remote add origin git@github.com:owner/repo.git 2> /dev/null || true
  main_at_start
  mkdir -p "$dir" "$REPO/openspec/specs/$cap"
  printf '# %s Specification\n\n## Requirements\n\n### Requirement: X\nThe system SHALL.\n\n#### Scenario: %s\n- **WHEN** a browser opens it\n- **THEN** %s\n' \
    "$cap" "$1" "$2" > "$REPO/openspec/specs/$cap/spec.md"
  printf 'png' > "$dir/$3"
  git -C "$REPO" add -A
  git -C "$REPO" commit -q -m '[7][abcdef] Add proof'
}

# [spec-coverage-d54754] A capability name with a dash still splits right.
test_spec_coverage_d54754_a_hash_id_proof_is_captioned() {
  hash_proof '[app-shell-beefed] Opens the menu' 'the menu opens' app-shell-beefed-opens-the-menu.png
  expect_pass proof_markdown HEAD
  expect_output '### [app-shell-beefed] Opens the menu'
  expect_output 'Expected: **THEN** the menu opens'
}

# "widgets-beefed-facade-x" could split more than one way: the split that names
# a scenario wins.
test_the_split_that_names_a_scenario_wins() {
  hash_proof '[widgets-beefed] Real' 'it is real' widgets-beefed-facade-x.png
  expect_pass proof_markdown HEAD
  expect_output '### [widgets-beefed] Real'
  expect_output 'Expected: **THEN** it is real'
}

# A test citing two scenarios is captioned from the first.
test_proof_markdown_two_ids_caption_from_the_first() {
  hash_proof '[widgets-1b2c3d] First' 'the first holds' widgets-1b2c3d-gadgets-4e5f6a-both.png
  expect_pass proof_markdown HEAD
  expect_output '### [widgets-1b2c3d] First'
}

# [spec-coverage-677a6a]
test_spec_coverage_677a6a_older_proof_is_left_out() {
  commit_proof openspec/changes/archive/2026-11-01-6-aaaaaa-old/proof
  git -C "$REPO" update-ref refs/remotes/origin/main HEAD
  mkdir -p "$REPO/openspec/changes/7-abcdef-thing/proof"
  printf 'png' > "$REPO/openspec/changes/7-abcdef-thing/proof/widgets-4d5e6f-another.png"
  git -C "$REPO" add -A
  git -C "$REPO" commit -q -m '[7][abcdef] Add proof'
  expect_pass proof_markdown HEAD
  expect_output '### [widgets-4d5e6f] Another'
  [[ "$OUT" != *'6-aaaaaa-old'* ]] || fail "older proof listed: $OUT"
  # With only older proof, there is nothing to show.
  git -C "$REPO" update-ref refs/remotes/origin/main HEAD
  expect_fail proof_markdown HEAD
  expect_output 'bin/e2e --proof'
}
