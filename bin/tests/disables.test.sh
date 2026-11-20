# shellcheck shell=bash disable=SC2154
# bin/check-disables.sh <kind>: each service's count of one kind of marked
# exception against its committed baseline file.

# Commits <baseline-file> holding <lines>, and each <path> with one <mark> line.
marks_commit() {
  local baseline_file="$1" lines="$2" mark="$3" path
  shift 3
  mkdir -p bin
  printf '%s\n' "$lines" > "$baseline_file"
  for path in "$@"; do
    mkdir -p "$(dirname "$path")"
    printf '%s\n' "$mark" "export const a = 1;" > "$path"
  done
  git add -A
  git commit -q -m "[1] Add marks"
}

# [repo-rules-925e9d]
test_repo_rules_925e9d_a_new_marked_clone_fails() {
  marks_commit bin/duplicate-disables.txt "api 0" "// jscpd:ignore-start x" services/api/src/a.ts
  expect_fail "$BIN/check-disables.sh" duplicates "$REPO"
  expect_output "api: 1 > 0"
  expect_output "services/api/src/a.ts:1"
  printf 'api 1\n' > bin/duplicate-disables.txt
  git commit -q -am "[1] Raise the baseline"
  expect_pass "$BIN/check-disables.sh" duplicates "$REPO"
}

# [repo-rules-0caa12]
test_repo_rules_0caa12_a_removed_mark_lowers_the_baseline() {
  marks_commit bin/duplicate-disables.txt "api 2" "// jscpd:ignore-start x" services/api/src/a.ts
  expect_fail "$BIN/check-disables.sh" duplicates "$REPO"
  expect_output "api: 1 < 2, commit bin/duplicate-disables.txt with api 1"
  printf 'api 1\n' > bin/duplicate-disables.txt
  git commit -q -am "[1] Lower the baseline"
  expect_pass "$BIN/check-disables.sh" duplicates "$REPO"
}

# [repo-rules-a36de1]
test_repo_rules_a36de1_generated_marks_are_not_counted() {
  marks_commit bin/duplicate-disables.txt $'api 0\nui 0' "// jscpd:ignore-start x" \
    services/api/src/generated/g.ts \
    services/api/contracts/c.ts \
    services/ui/src/services/graphql/generated/gql.ts
  expect_pass "$BIN/check-disables.sh" duplicates "$REPO"
}

test_other_kinds_marks_are_not_counted() {
  marks_commit bin/duplicate-disables.txt "api 0" "// eslint-disable-next-line x -- y" services/api/src/a.ts
  expect_pass "$BIN/check-disables.sh" duplicates "$REPO"
}

test_check_disables_usage() {
  expect_pass "$BIN/check-disables.sh" --help
  expect_output "Usage: bin/check-disables.sh <kind>"
  expect_output "duplicates"
  expect_output "unused"
  expect_output "imports"
  expect_output "mutations"
  expect_fail "$BIN/check-disables.sh" bogus "$REPO"
  expect_output "Usage:"
  expect_fail "$BIN/check-disables.sh"
  expect_fail "$BIN/check-disables.sh" duplicates "$REPO" extra
}

# [repo-rules-69f853]
test_repo_rules_69f853_a_new_unused_exception_fails() {
  marks_commit bin/unused-disables.txt "api 0" "/** @knipignore x */" services/api/src/a.ts
  mkdir -p services/api
  printf '%s\n' '  ignoreDependencies: ["x"], // knipignore: y' > services/api/knip.config.ts
  git add -A
  git commit -q -m "[1] Ignore a dependency"
  expect_fail "$BIN/check-disables.sh" unused "$REPO"
  expect_output "api: 2 > 0"
  expect_output "services/api/src/a.ts:1"
  expect_output "services/api/knip.config.ts:1"
  printf 'api 2\n' > bin/unused-disables.txt
  git commit -q -am "[1] Raise the baseline"
  expect_pass "$BIN/check-disables.sh" unused "$REPO"
}

# [repo-rules-ba4550]
test_repo_rules_ba4550_a_removed_unused_exception_lowers_the_baseline() {
  marks_commit bin/unused-disables.txt "api 2" "/** @knipignore x */" services/api/src/a.ts
  expect_fail "$BIN/check-disables.sh" unused "$REPO"
  expect_output "api: 1 < 2, commit bin/unused-disables.txt with api 1"
}

test_the_knip_tag_setting_is_not_counted() {
  marks_commit bin/unused-disables.txt "api 0" '  tags: ["-knipignore"],' services/api/knip.config.ts
  expect_pass "$BIN/check-disables.sh" unused "$REPO"
}

# [repo-rules-42b923]
test_repo_rules_42b923_a_new_import_exception_fails() {
  marks_commit bin/import-disables.txt "api 0" '      pathNot: "^src/a\\.ts$", // import-exception: x' services/api/.dependency-cruiser.mjs
  expect_fail "$BIN/check-disables.sh" imports "$REPO"
  expect_output "api: 1 > 0"
  expect_output "services/api/.dependency-cruiser.mjs:1"
  printf 'api 1\n' > bin/import-disables.txt
  git commit -q -am "[1] Raise the baseline"
  expect_pass "$BIN/check-disables.sh" imports "$REPO"
}

# [repo-rules-c362cb]
test_repo_rules_c362cb_a_removed_import_exception_lowers_the_baseline() {
  marks_commit bin/import-disables.txt "api 2" "// import-exception: x" services/api/.dependency-cruiser.mjs
  expect_fail "$BIN/check-disables.sh" imports "$REPO"
  expect_output "api: 1 < 2, commit bin/import-disables.txt with api 1"
}

# [repo-rules-a36de1]: only the generated contracts/ folder at a service's
# root is excluded, not a hand-written src/contracts/.
test_hand_written_contracts_code_is_counted() {
  marks_commit bin/duplicate-disables.txt "api 0" "// jscpd:ignore-start x" services/api/src/contracts/a.ts
  expect_fail "$BIN/check-disables.sh" duplicates "$REPO"
  expect_output "services/api/src/contracts/a.ts:1"
}

# [repo-rules-69f853]: Knip's @public and @beta tags hide an export too; the
# tags it still reports (@alpha, @internal) are not exceptions.
test_release_tags_count_as_unused_exceptions() {
  marks_commit bin/unused-disables.txt "api 0" "/** @public */" services/api/src/a.ts
  printf '%s\n' "/** @beta */" "/** @alpha */" "/** @internal */" > services/api/src/b.ts
  git add -A
  git commit -q -m "[1] Tag exports"
  expect_fail "$BIN/check-disables.sh" unused "$REPO"
  expect_output "api: 2 > 0"
  expect_output "services/api/src/b.ts:1"
}

MARKER='// Stryker disable next-line Regex,StringLiteral: the anchors are redundant here'

# [repo-rules-b0b547]
test_repo_rules_b0b547_a_new_marker_fails() {
  marks_commit bin/mutation-disables.txt "api 0" "$MARKER" services/api/src/a.ts
  expect_fail "$BIN/check-disables.sh" mutations "$REPO"
  expect_output "api: 1 > 0 equivalent-mutant markers in bin/mutation-disables.txt"
  expect_output "services/api/src/a.ts:1"
  printf 'api 1\n' > bin/mutation-disables.txt
  git commit -q -am "[1] Raise the baseline"
  expect_pass "$BIN/check-disables.sh" mutations "$REPO"
}

# [repo-rules-76b314]
test_repo_rules_76b314_a_removed_marker_lowers_the_baseline() {
  marks_commit bin/mutation-disables.txt "api 2" "$MARKER" services/api/src/a.ts
  expect_fail "$BIN/check-disables.sh" mutations "$REPO"
  expect_output "api: 1 < 2, commit bin/mutation-disables.txt with api 1"
  printf 'api 1\n' > bin/mutation-disables.txt
  git commit -q -am "[1] Lower the baseline"
  expect_pass "$BIN/check-disables.sh" mutations "$REPO"
}

# [repo-rules-cdf0be]
test_repo_rules_cdf0be_generated_and_untracked_markers_are_not_counted() {
  marks_commit bin/mutation-disables.txt $'api 0\nui 0' "$MARKER" \
    services/api/src/generated/g.ts \
    services/api/contracts/c.ts \
    services/ui/src/services/graphql/generated/gql.ts
  printf '%s\n' "$MARKER" > services/api/README.md
  git add -A
  git commit -q -m "[1] Add docs"
  printf '%s\n' "$MARKER" > services/api/src/new.ts
  expect_pass "$BIN/check-disables.sh" mutations "$REPO"
}

# [repo-rules-3e3d9b]
test_repo_rules_3e3d9b_a_marker_in_another_form_is_rejected() {
  local marker
  for marker in \
    '// Stryker disable next-line Regex' \
    '// Stryker disable next-line Regex:' \
    '// Stryker disable next-line all: no test can tell' \
    '// Stryker disable next-line Regex,all: no test can tell' \
    '// Stryker disable next-line: no mutator named' \
    '// Stryker disable Regex: the whole file' \
    '// Stryker disable all' \
    '/* Stryker disable next-line Regex */ export const b = 2;' \
    '/* Stryker disable next-line Regex: a block comment */'; do
    marks_commit bin/mutation-disables.txt "api 0" "$marker" services/api/src/a.ts
    expect_fail "$BIN/check-disables.sh" mutations "$REPO"
    expect_output "services/api/src/a.ts:1: not // Stryker disable next-line <mutator>: <reason>"
  done
}

test_a_rejected_marker_fails_even_when_counts_match() {
  marks_commit bin/mutation-disables.txt "api 1" "// Stryker disable all" services/api/src/a.ts
  expect_fail "$BIN/check-disables.sh" mutations "$REPO"
  expect_output "api: 0 < 1"
  printf 'api 0\n' > bin/mutation-disables.txt
  git commit -q -am "[1] Lower the baseline"
  expect_fail "$BIN/check-disables.sh" mutations "$REPO"
  expect_output "services/api/src/a.ts:1: not // Stryker disable next-line"
}

# [repo-rules-8ccd75]
test_repo_rules_8ccd75_markers_in_the_one_form_pass() {
  marks_commit bin/mutation-disables.txt "api 3" "$MARKER" services/api/src/a.ts services/api/tests/a.test.ts
  printf '%s\n' 'const x = 1; // Stryker disable next-line Regex: after code' > services/api/src/b.ts
  printf '%s\n' '// Stryker restore all' > services/api/src/c.ts
  git add -A
  git commit -q -m "[1] Block comment, restore and a test file"
  expect_pass "$BIN/check-disables.sh" mutations "$REPO"
}

test_mutation_markers_do_not_count_for_other_kinds() {
  marks_commit bin/duplicate-disables.txt "api 0" "$MARKER" services/api/src/a.ts
  expect_pass "$BIN/check-disables.sh" duplicates "$REPO"
}
