# shellcheck shell=bash disable=SC2154
# bin/mutate against a fake docker that logs its calls: which service it
# refuses, which lines it hands Stryker, and when it starts nothing at all.
# The real run is bin/tests/mutate.e2e.sh.

setup_mutate() {
  mkdir -p "$REPO/bin" "$REPO/fakes" "$REPO/services/api/src" "$REPO/services/plain"
  cp "$BIN/mutate" "$BIN/factory-jobs.sh" "$REPO/bin/"
  printf '{}\n' > "$REPO/services/api/package.json"
  printf 'FROM base AS checks\nFROM checks AS mutate\n' > "$REPO/services/api/Dockerfile"
  printf '{}\n' > "$REPO/services/plain/package.json"
  printf 'FROM base AS checks\n' > "$REPO/services/plain/Dockerfile"
  seq 1 12 | sed 's/^/export const a/; s/$/ = 1;/' > "$REPO/services/api/src/a.ts"
  seq 1 12 | sed 's/^/export const b/; s/$/ = 1;/' > "$REPO/services/api/src/b.ts"
  seq 1 6 | sed 's/^/export const C/; s/$/ = () => <p>c<\/p>;/' > "$REPO/services/api/src/c.tsx"
  printf 'tmp/\nfakes/\ndocker-calls\nenv\n' > "$REPO/.gitignore"
  git add -A
  git commit -q -m "[1] Add the service"
  git update-ref refs/remotes/origin/main HEAD
  export FACTORY_JOBS=3 FACTORY_ENV_FILE="$REPO/env" MUTATE_TRACE="$REPO/docker-calls"
  cat > "$REPO/fakes/docker" <<'DOCKER'
#!/usr/bin/env bash
set -eu
printf '%s\n' "$*" >> "$MUTATE_TRACE"
case "$1" in
  build|rm|image) ;;
  run) echo "stryker output"; exit "${RUN_EXIT:-0}" ;;
  cp) mkdir -p "$3"; printf 'summary\n' > "$3/summary.md" ;;
  *) exit 2 ;;
esac
DOCKER
  chmod +x "$REPO/fakes/docker"
  export PATH="$REPO/fakes:$PATH"
  MUTATE="$REPO/bin/mutate"
}

docker_calls() { cat "$MUTATE_TRACE" 2>/dev/null || true; }
run_call() { docker_calls | grep '^run ' || true; }

commit_all() {
  git add -A
  git commit -q -m "[1] $1"
}

test_help_and_usage_errors() {
  setup_mutate
  expect_pass "$MUTATE" --help
  expect_output "usage: bin/mutate <service> [--changed] [--base <ref>]"
  expect_output "MUTATE_FULL_GLOB"
  expect_fail "$MUTATE"
  expect_output "usage:"
  expect_fail "$MUTATE" api --nope
  expect_output "usage:"
  expect_fail "$MUTATE" api --base
  expect_output "usage:"
  expect_fail "$MUTATE" api api
  expect_output "usage:"
  [ -z "$(docker_calls)" ] || fail "docker called: $(docker_calls)"
}

# [service-checks-37bce9]
test_service_checks_37bce9_a_service_without_a_mutate_target_is_refused() {
  setup_mutate
  expect_fail "$MUTATE" plain
  expect_output "plain has no mutate target"
  expect_fail "$MUTATE" missing --changed
  expect_output "Unknown service"
  [ -z "$(docker_calls)" ] || fail "docker called: $(docker_calls)"
}

# [service-checks-a98197]
test_service_checks_a98197_no_changed_source_starts_nothing() {
  setup_mutate
  mkdir -p services/api/tests
  printf 'test\n' > services/api/tests/a.test.ts
  printf 'notes\n' > README.md
  printf 'x\n' > services/api/src/readme.md
  commit_all "Change no source"
  expect_pass "$MUTATE" api --changed
  expect_output "Nothing to mutate."
  [ -z "$(docker_calls)" ] || fail "docker called: $(docker_calls)"
}

test_only_deleted_lines_are_nothing_to_mutate() {
  setup_mutate
  sed -i.bak '3,4d' services/api/src/a.ts && rm services/api/src/a.ts.bak
  commit_all "Delete lines"
  expect_pass "$MUTATE" api --changed
  expect_output "Nothing to mutate."
  [ -z "$(docker_calls)" ] || fail "docker called: $(docker_calls)"
}

# A changed line's range, whatever the user's diff prefix setting.
ranges_with_setting() {
  setup_mutate
  git config "$1" true
  sed -i.bak 's/b10 = 1/b10 = 2/' services/api/src/b.ts
  rm services/api/src/*.bak
  expect_pass "$MUTATE" api --changed
  [[ "$(run_call)" == *" bun tooling/mutate.ts --changed src/b.ts:10-10" ]] || fail "$1 ranges: $(run_call)"
}

test_ranges_ignore_a_mnemonic_diff_prefix() {
  ranges_with_setting diff.mnemonicPrefix
}

test_ranges_ignore_a_missing_diff_prefix() {
  ranges_with_setting diff.noprefix
}

test_changed_lines_are_passed_as_ranges() {
  setup_mutate
  sed -i.bak '2a\
export const x1 = 2;\
export const x2 = 2;\
export const x3 = 2;
' services/api/src/a.ts
  sed -i.bak 's/b10 = 1/b10 = 2/' services/api/src/b.ts
  sed -i.bak 's/C4 = /C4 = () => null; export const D4 = /' services/api/src/c.tsx
  rm services/api/src/*.bak
  commit_all "Change two files"
  expect_pass "$MUTATE" api --changed
  [[ "$(run_call)" == *" bun tooling/mutate.ts --changed src/a.ts:3-5 src/b.ts:10-10 src/c.tsx:4-4" ]] || fail "ranges: $(run_call)"
  [[ "$(run_call)" == *"-e FACTORY_JOBS=3"* ]] || fail "jobs: $(run_call)"
  docker_calls | grep -q '^build --target mutate ' || fail "no mutate build: $(docker_calls)"
  expect_output "api: passed"
  out="$(printf '%s\n' "$OUT" | sed -n 's/^Reports: //p')"
  [ -f "$out/summary.md" ] || fail "reports not kept: $OUT"
  [[ "$out" == "$(cd "$REPO" && pwd -P)/tmp/mutate/api/run."* ]] || fail "reports folder: $out"
  docker_calls | grep -q '^rm ' || fail "container not removed: $(docker_calls)"
  docker_calls | grep -q '^image rm ' || fail "image not removed: $(docker_calls)"
}

test_base_selects_what_counts_as_changed() {
  setup_mutate
  sed -i.bak 's/a1 = 1/a1 = 2/' services/api/src/a.ts && rm services/api/src/a.ts.bak
  commit_all "First"
  sed -i.bak 's/a7 = 1/a7 = 2/' services/api/src/a.ts && rm services/api/src/a.ts.bak
  commit_all "Second"
  expect_pass "$MUTATE" api --changed --base HEAD~1
  [[ "$(run_call)" == *" --changed src/a.ts:7-7" ]] || fail "--base: $(run_call)"
  : > "$MUTATE_TRACE"
  expect_pass "$MUTATE" api --changed
  [[ "$(run_call)" == *" --changed src/a.ts:1-1 src/a.ts:7-7" ]] || fail "merge base: $(run_call)"
  expect_fail "$MUTATE" api --changed --base nope
  expect_output "nope"
}

test_uncommitted_and_untracked_source_counts_as_changed() {
  setup_mutate
  sed -i.bak 's/b2 = 1/b2 = 2/' services/api/src/b.ts && rm services/api/src/b.ts.bak
  printf 'export const e = 1;\nexport const f = 2;\n' > services/api/src/e.ts
  expect_pass "$MUTATE" api --changed
  [[ "$(run_call)" == *" --changed src/b.ts:2-2 src/e.ts:1-2" ]] || fail "working tree: $(run_call)"
}

# [service-checks-b71438]
test_service_checks_b71438_a_run_keeps_its_reports_in_a_new_folder() {
  local first second
  setup_mutate
  sed -i.bak 's/a1 = 1/a1 = 2/' services/api/src/a.ts && rm services/api/src/a.ts.bak
  commit_all "Change"
  RUN_EXIT=1 expect_fail "$MUTATE" api --changed
  expect_output "stryker output"
  expect_output "api: failed"
  first="$(printf '%s\n' "$OUT" | sed -n 's/^Reports: //p')"
  [ -f "$first/summary.md" ] || fail "reports not kept: $OUT"
  expect_pass "$MUTATE" api --changed
  expect_output "api: passed"
  second="$(printf '%s\n' "$OUT" | sed -n 's/^Reports: //p')"
  [ -f "$second/summary.md" ] || fail "reports not kept: $OUT"
  [ "$first" != "$second" ] || fail "both runs reported into $first"
}

test_a_full_run_mutates_everything_and_passes_the_glob() {
  setup_mutate
  MUTATE_FULL_GLOB=src/a.ts expect_pass "$MUTATE" api
  [[ "$(run_call)" == *" bun tooling/mutate.ts" ]] || fail "full: $(run_call)"
  [[ "$(run_call)" == *"-e MUTATE_FULL_GLOB=src/a.ts"* ]] || fail "glob: $(run_call)"
}

test_a_base_that_moved_ahead_counts_only_the_branchs_changes() {
  setup_mutate
  git checkout -q -b feature
  sed -i.bak 's/a1 = 1/a1 = 2/' services/api/src/a.ts && rm services/api/src/a.ts.bak
  commit_all "Branch change"
  git checkout -q main
  sed -i.bak 's/a7 = 1/a7 = 3/' services/api/src/a.ts && rm services/api/src/a.ts.bak
  commit_all "Main moves on"
  git checkout -q feature
  expect_pass "$MUTATE" api --changed --base main
  [[ "$(run_call)" == *" --changed src/a.ts:1-1" ]] || fail "base tip, not merge base: $(run_call)"
}
