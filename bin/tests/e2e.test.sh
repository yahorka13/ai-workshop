# shellcheck shell=bash disable=SC2154
# bin/e2e against a fake docker: what it runs, where the evidence lands, and
# when it refuses. The fixture worktree's path holds a space.

setup_e2e() {
  WT="$REPO/work tree"
  mkdir -p "$WT/bin" "$WT/services/e2e" "$WT/fakes" "$WT/openspec/changes/archive"
  cd "$WT" || exit 1
  git init -q -b main
  git config user.name Test
  git config user.email test@example.com
  git commit -q --allow-empty -m "[1] Initial"
  cp "$BIN/e2e" "$BIN/compose" "$WT/bin/"
  touch "$WT/services/e2e/package.json" "$WT/services/e2e/Dockerfile" "$WT/.env"
  session_file 127.0.0.1
  export E2E_TRACE="$WT/docker-calls" UI_RUNNING=1
  : > "$E2E_TRACE"
  cat > "$WT/fakes/docker" <<'DOCKER'
#!/usr/bin/env bash
set -eu
printf '%s\n' "$*" >> "$E2E_TRACE"
case "$1" in
  compose) [ "$UI_RUNNING" = 1 ] && printf 'backend\nui\n' || printf 'backend\n' ;;
  build | buildx) [ "${FAIL_PHASE:-}" != image ] ;;
  run) [ "${FAIL_PHASE:-}" != "${*: -1}" ] ;;
  create | rm | image) ;;
  start)
    [ "${SLOW_START:-}" != 1 ] || sleep 5
    [ "${FAIL_PHASE:-}" != suite ] ;;
  cp)
    mkdir -p "$3/$(basename "${2#*:}")"
    if [ "$(basename "${2#*:}")" = proof ]; then
      # The proof reporter's files: a video only when the run asked for one.
      touch "$3/proof/app-shell-af1ebe-the-home-screen-shows-the-layout.png"
      ! grep -q '^create .*E2E_VIDEO=1' "$E2E_TRACE" || touch "$3/proof/app-shell-af1ebe-the-home-screen-shows-the-layout.webm"
    else
      touch "$3/$(basename "${2#*:}")/index.html"
    fi ;;
  *) exit 2 ;;
esac
DOCKER
  chmod +x "$WT/fakes/docker"
  export PATH="$WT/fakes:$PATH"
}

# session_file <public host>: the .env.session bin/up writes for slot 7.
session_file() {
  printf 'COMPOSE_PROJECT_NAME=factory-7\nFACTORY_PUBLIC_HOST=%s\nFACTORY_PORT_UI=16000\nFACTORY_PORT_API=16002\n' "$1" > "$WT/.env.session"
}

create_line() { grep '^create ' "$E2E_TRACE" || true; }

# [spec-coverage-d72d48]
test_spec_coverage_d72d48_a_passing_suite_keeps_its_report() {
  setup_e2e
  expect_pass bin/e2e
  expect_output "$WT/tmp/e2e/"
  ls "$WT"/tmp/e2e/run.*/playwright-report/index.html > /dev/null || fail 'report not kept'
  ls -d "$WT"/tmp/e2e/run.*/test-results > /dev/null || fail 'traces not kept'
  grep -q '^build .*services/e2e' "$E2E_TRACE" || fail 'image not built from services/e2e'
}

# [spec-coverage-762db8]
test_spec_coverage_762db8_a_failing_test_fails_the_run() {
  setup_e2e
  export FAIL_PHASE=suite
  expect_fail bin/e2e
  expect_output 'playwright-report/index.html'
  ls "$WT"/tmp/e2e/run.*/playwright-report/index.html > /dev/null || fail 'report not kept'
}

# [spec-coverage-54237b]
test_spec_coverage_54237b_no_container_or_image_is_left() {
  setup_e2e
  expect_pass bin/e2e
  grep -q '^rm -f factory-e2e-' "$E2E_TRACE" || fail 'container not removed'
  grep -q '^image rm factory-e2e:' "$E2E_TRACE" || fail 'image not removed'
  : > "$E2E_TRACE"
  export SLOW_START=1
  bin/e2e > /dev/null 2>&1 &
  local pid=$! waited=0
  until grep -q '^start ' "$E2E_TRACE" || [ "$waited" -ge 50 ]; do sleep 0.1; waited=$((waited + 1)); done
  kill -INT "$pid"
  wait "$pid" || true
  grep -q '^rm -f factory-e2e-' "$E2E_TRACE" || fail 'interrupted run left its container'
  grep -q '^image rm factory-e2e:' "$E2E_TRACE" || fail 'interrupted run left its image'
}

# [spec-coverage-2183dd]
test_spec_coverage_2183dd_suite_gets_the_slot_urls_without_host_networking() {
  setup_e2e
  expect_pass bin/e2e
  local create
  create="$(create_line)"
  [[ "$create" == *"--network factory-7_private"* ]] || fail "not on the stack's network: $create"
  [[ "$create" != *"--network host"* ]] || fail "on the host's network: $create"
  [[ "$create" == *"E2E_BASE_URL=http://127.0.0.1:16000"* ]] || fail "no app URL: $create"
  [[ "$create" == *"E2E_API_URL=http://127.0.0.1:16002"* ]] || fail "no API URL: $create"
  [[ "$create" == *"E2E_FORWARDS=16000=ui:3000,16002=backend:4000"* ]] || fail "no forwards: $create"
  [[ "$create" == *" bunx playwright test" ]] || fail "suite not run: $create"
  [[ "$create" != *"--add-host"* ]] || fail "a needless host entry: $create"
  # An empty public host means the default, 127.0.0.1.
  session_file ''
  : > "$E2E_TRACE"
  expect_pass bin/e2e
  [[ "$(create_line)" == *"E2E_BASE_URL=http://127.0.0.1:16000"* ]] || fail "no default host: $(create_line)"
}

# [spec-coverage-746b78]
test_spec_coverage_746b78_a_public_host_resolves_to_the_forwarders() {
  setup_e2e
  session_file box.example.test
  expect_pass bin/e2e
  local create
  create="$(create_line)"
  [[ "$create" == *"--add-host box.example.test:127.0.0.1"* ]] || fail "the name does not resolve to the forwarders: $create"
  [[ "$create" == *"E2E_BASE_URL=http://box.example.test:16000"* ]] || fail "URL not on the public host: $create"
  [[ "$create" == *"E2E_API_URL=http://box.example.test:16002"* ]] || fail "API URL not on the public host: $create"
}

# [spec-coverage-a3ede3]
test_spec_coverage_a3ede3_no_stack_no_run() {
  setup_e2e
  rm "$WT/.env.session"
  expect_fail bin/e2e
  expect_output 'bin/up'
  session_file 127.0.0.1
  export UI_RUNNING=0
  expect_fail bin/e2e
  expect_output 'bin/up'
  ! grep -qE '^(create|build) ' "$E2E_TRACE" || fail "ran without a stack: $(cat "$E2E_TRACE")"
}

# [spec-coverage-a905e7]
test_spec_coverage_a905e7_arguments_pass_through() {
  setup_e2e
  expect_pass bin/e2e -- --grep '\[app-shell-af1ebe\]' --headed
  [[ "$(create_line)" == *' bunx playwright test --grep \[app-shell-af1ebe\] --headed' ]] || fail "arguments changed: $(create_line)"
}

# [spec-coverage-ab430a]
test_spec_coverage_ab430a_gates_run_lint_then_typecheck() {
  setup_e2e
  rm "$WT/.env.session"
  expect_pass bin/e2e --gates
  [ "$(sed -n 's/^run --rm factory-e2e:[a-z0-9]* bun run //p' "$E2E_TRACE")" = $'lint\ntypecheck' ] || fail "wrong gates: $(cat "$E2E_TRACE")"
  ! grep -q '^create ' "$E2E_TRACE" || fail 'ran the suite'
}

# [spec-coverage-230e5d]
test_spec_coverage_230e5d_a_failed_gate_fails_the_run() {
  setup_e2e
  local phase
  for phase in image lint typecheck; do
    export FAIL_PHASE="$phase"
    : > "$E2E_TRACE"
    expect_fail bin/e2e --gates
    expect_output "e2e: $phase failed"
  done
  export FAIL_PHASE=lint
  : > "$E2E_TRACE"
  expect_fail bin/e2e --gates
  ! grep -q ' bun run typecheck$' "$E2E_TRACE" || fail 'typecheck ran after lint failed'
}

# [spec-coverage-a93813]
test_spec_coverage_a93813_help_names_the_modes() {
  setup_e2e
  expect_pass bin/e2e --help
  local word
  for word in --changed --gates ' -- ' tmp/e2e/ bin/up; do
    expect_output "$word"
  done
}

# changed_spec <capability> <requirement text> <scenario ID>...: write
# openspec/specs/<capability>/spec.md with one requirement, "<capability>
# behaves", holding one scenario per ID.
changed_spec() {
  local cap="$1" text="$2" id
  shift 2
  mkdir -p "$WT/openspec/specs/$cap"
  {
    printf '# %s Specification\n\n## Purpose\nThe %s fixture capability of the bin/e2e --changed tests.\n\n## Requirements\n' "$cap" "$cap"
    printf '\n### Requirement: %s behaves\n%s\n' "$cap" "$text"
    for id in "$@"; do
      printf '\n#### Scenario: [%s] Case %s\n- **WHEN** it happens\n- **THEN** it works\n' "$id" "$id"
    done
  } > "$WT/openspec/specs/$cap/spec.md"
}

# A base on origin/main with widgets and gizmos specs, and suite tests citing
# some of widgets's scenarios, a moved one and a scenario an active change may add.
changed_fixture() {
  setup_e2e
  cp "$BIN/spec" "$WT/bin/"
  export OPENSPEC="$BIN/openspec"
  changed_spec widgets 'The widgets SHALL list players.' widgets-1a2b3c widgets-3c4d5e widgets-a0b1c2 gadgets-7e8f9a
  changed_spec gizmos 'Gizmos SHALL run the checks.' gizmos-1f2e3d
  mkdir -p "$WT/services/e2e/tests"
  cat > "$WT/services/e2e/tests/widgets.spec.ts" <<'TS'
test("[widgets-1a2b3c] lists players", () => {});
test("[widgets-a0b1c2] [gadgets-7e8f9a] lists the moved gadget", () => {});
test("[widgets-abc123] lists the new thing", () => {});
TS
  printf 'docker-calls\ntmp/\nfakes/\n' > "$WT/.gitignore"
  git -C "$WT" add -A && git -C "$WT" commit -q -m '[1] Base'
  git -C "$WT" update-ref refs/remotes/origin/main HEAD
}

# The Playwright arguments of the suite's container.
playwright_args() { create_line | sed -n 's/.* bunx playwright test//p'; }

# [spec-coverage-5cf1ec]
test_spec_coverage_5cf1ec_only_the_changed_capability_runs() {
  changed_fixture
  changed_spec widgets 'The widgets SHALL list every player.' widgets-1a2b3c widgets-3c4d5e widgets-a0b1c2 gadgets-7e8f9a
  git -C "$WT" commit -qam '[1] Change widgets'
  expect_pass bin/e2e --changed
  expect_output 'e2e: changed capabilities: widgets'
  [ "$(playwright_args)" = ' --grep \[(gadgets-7e8f9a|widgets-1a2b3c|widgets-a0b1c2)\]' ] || fail "wrong selection: $(create_line)"
}

# [spec-coverage-5cf1ec]
test_spec_coverage_5cf1ec_a_moved_requirement_counts_both_sides() {
  changed_fixture
  local deploys='\n### Requirement: deploys behave\nDeploys SHALL roll out.\n\n#### Scenario: [gizmos-2b3c4d] Case gizmos-2b3c4d\n- **WHEN** it happens\n- **THEN** it works\n'
  # shellcheck disable=SC2059 # the fixture text is the format
  printf "$deploys" >> "$WT/openspec/specs/gizmos/spec.md"
  git -C "$WT" commit -qam '[1] Add to gizmos'
  git -C "$WT" update-ref refs/remotes/origin/main HEAD
  # Move "deploys behave" from gizmos to widgets, unchanged.
  changed_spec gizmos 'Gizmos SHALL run the checks.' gizmos-1f2e3d
  # shellcheck disable=SC2059 # the fixture text is the format
  printf "$deploys" >> "$WT/openspec/specs/widgets/spec.md"
  git -C "$WT" commit -qam '[1] Move deploys'
  expect_pass bin/e2e --changed
  expect_output 'e2e: changed capabilities: gizmos widgets'
}

# [spec-coverage-df6711]
test_spec_coverage_df6711_a_changes_delta_counts() {
  changed_fixture
  local change="$WT/openspec/changes/1-abc123-thing"
  mkdir -p "$change/specs/widgets"
  printf 'schema: spec-driven\n' > "$change/.openspec.yaml"
  printf '# Proposal\n\n## Why\nA fixture change for the bin/e2e --changed tests.\n\n## What Changes\n- widgets lists a new thing\n' > "$change/proposal.md"
  printf '## ADDED Requirements\n\n### Requirement: widgets lists new things\nThe widgets SHALL list new things.\n\n#### Scenario: [widgets-abc123] New thing\n- **WHEN** it happens\n- **THEN** it works\n' \
    > "$change/specs/widgets/spec.md"
  git -C "$WT" add -A && git -C "$WT" commit -qm '[1] Add a change'
  expect_pass bin/e2e --changed
  expect_output 'e2e: changed capabilities: widgets'
  [ "$(playwright_args)" = ' --grep \[(gadgets-7e8f9a|widgets-1a2b3c|widgets-a0b1c2|widgets-abc123)\]' ] || fail "wrong selection: $(create_line)"
}

# [spec-coverage-15915f]
test_spec_coverage_15915f_extra_arguments_pass_through() {
  changed_fixture
  changed_spec widgets 'The widgets SHALL list every player.' widgets-1a2b3c widgets-3c4d5e widgets-a0b1c2 gadgets-7e8f9a
  git -C "$WT" commit -qam '[1] Change widgets'
  expect_pass bin/e2e --changed -- --workers 1
  [ "$(playwright_args)" = ' --grep \[(gadgets-7e8f9a|widgets-1a2b3c|widgets-a0b1c2)\] --workers 1' ] || fail "arguments lost: $(create_line)"
}

# [spec-coverage-c85dc1]
test_spec_coverage_c85dc1_no_spec_change_runs_everything() {
  changed_fixture
  expect_pass bin/e2e --changed
  expect_output 'e2e: the branch changes no specs; running the full suite'
  [ -z "$(playwright_args)" ] || fail "not the full suite: $(create_line)"
  [[ "$(create_line)" == *' bunx playwright test' ]] || fail "suite not run: $(create_line)"
}

# [spec-coverage-dc0f63]
test_spec_coverage_dc0f63_only_uncited_capabilities_run_nothing() {
  changed_fixture
  changed_spec gizmos 'Gizmos SHALL run every check.' gizmos-1f2e3d
  git -C "$WT" commit -qam '[1] Change gizmos'
  rm "$WT/.env.session"
  expect_pass bin/e2e --changed
  expect_output 'e2e: changed capabilities: gizmos'
  expect_output 'e2e: no end-to-end tests in the suite: gizmos'
  expect_output 'nothing to run'
  [ ! -s "$E2E_TRACE" ] || fail "touched Docker: $(cat "$E2E_TRACE")"
  # With widgets changed as well, gizmos is named and only widgets's tests run.
  session_file 127.0.0.1
  changed_spec widgets 'The widgets SHALL list every player.' widgets-1a2b3c widgets-3c4d5e widgets-a0b1c2 gadgets-7e8f9a
  git -C "$WT" commit -qam '[1] Change widgets'
  expect_pass bin/e2e --changed
  expect_output 'e2e: no end-to-end tests in the suite: gizmos'
  [ "$(playwright_args)" = ' --grep \[(gadgets-7e8f9a|widgets-1a2b3c|widgets-a0b1c2)\]' ] || fail "wrong selection: $(create_line)"
}

# [spec-coverage-6144af]
test_spec_coverage_6144af_conflicting_selections_are_refused() {
  setup_e2e
  local args status
  for args in '--changed --gates' '--gates --changed' '--changed -- --grep x' '--changed -- -g x' \
    '--changed -- --grep=x' '--changed -- -gx' '--gates -- --grep x' '--nope'; do
    status=0
    # shellcheck disable=SC2086 # split on purpose
    OUT="$(bin/e2e $args 2>&1)" || status=$?
    [ "$status" -eq 2 ] || fail "bin/e2e $args exited $status"$'\n'"$OUT"
    expect_output 'usage:'
  done
  ! grep -q '^create ' "$E2E_TRACE" || fail 'ran a refused selection'
}

test_e2e_changed_unreadable_spec_fails() {
  changed_fixture
  printf '# broken\n\nnot a spec\n' > "$WT/openspec/specs/widgets/spec.md"
  git -C "$WT" commit -qam '[1] Break widgets'
  expect_fail bin/e2e --changed
  expect_output 'openspec/specs/widgets/spec.md'
  [ ! -s "$E2E_TRACE" ] || fail "touched Docker: $(cat "$E2E_TRACE")"
}

PROOF_NAME=app-shell-af1ebe-the-home-screen-shows-the-layout

# [spec-coverage-de027b]
test_spec_coverage_de027b_proof_lands_in_the_change() {
  setup_e2e
  mkdir -p "$WT/openspec/changes/7-aaaaaa-x"
  expect_pass bin/e2e --proof -- --grep '\[app-shell-af1ebe\]'
  local proof="$WT/openspec/changes/7-aaaaaa-x/proof"
  [ -f "$proof/$PROOF_NAME.png" ] || fail 'screenshot not copied'
  [ ! -e "$proof/$PROOF_NAME.webm" ] || fail 'a video without --video'
  expect_output "e2e: proof: openspec/changes/7-aaaaaa-x/proof/$PROOF_NAME.png"
  [[ "$(create_line)" == *"E2E_PROOF=1"* ]] || fail "proof not asked for: $(create_line)"
  [[ "$(create_line)" != *"E2E_VIDEO"* ]] || fail "video asked for: $(create_line)"
  # A second run overwrites the same file.
  expect_pass bin/e2e --proof
  [ -f "$proof/$PROOF_NAME.png" ] || fail 'second run lost the screenshot'
}

# [spec-coverage-9c88ca]
test_spec_coverage_9c88ca_a_failing_proof_run_copies_nothing() {
  setup_e2e
  mkdir -p "$WT/openspec/changes/7-aaaaaa-x"
  export FAIL_PHASE=suite
  expect_fail bin/e2e --proof
  [ ! -d "$WT/openspec/changes/7-aaaaaa-x/proof" ] || fail 'proof copied from a failing run'
}

# [spec-coverage-f21527]
test_spec_coverage_f21527_video_only_on_request() {
  setup_e2e
  mkdir -p "$WT/openspec/changes/7-aaaaaa-x"
  expect_pass bin/e2e --proof --video
  [[ "$(create_line)" == *"E2E_VIDEO=1"* ]] || fail "video not asked for: $(create_line)"
  [ -f "$WT/openspec/changes/7-aaaaaa-x/proof/$PROOF_NAME.png" ] || fail 'screenshot not copied'
  [ -f "$WT/openspec/changes/7-aaaaaa-x/proof/$PROOF_NAME.webm" ] || fail 'video not copied'
}

# [spec-coverage-babb03]
test_spec_coverage_babb03_the_flag_picks_the_change() {
  setup_e2e
  mkdir -p "$WT/openspec/changes/7-aaaaaa-x" "$WT/openspec/changes/7-bbbbbb-y"
  git checkout -q -b 7-aaaaaa-x
  expect_pass bin/e2e --proof --change 7-bbbbbb-y
  [ -f "$WT/openspec/changes/7-bbbbbb-y/proof/$PROOF_NAME.png" ] || fail '--change not used'
  [ ! -d "$WT/openspec/changes/7-aaaaaa-x/proof" ] || fail "the branch's change was used"
}

# [spec-coverage-b9a4f9]
test_spec_coverage_b9a4f9_the_branchs_change_by_default() {
  setup_e2e
  mkdir -p "$WT/openspec/changes/7-aaaaaa-x" "$WT/openspec/changes/7-bbbbbb-y"
  git checkout -q -b 7-aaaaaa-x
  expect_pass bin/e2e --proof
  [ -f "$WT/openspec/changes/7-aaaaaa-x/proof/$PROOF_NAME.png" ] || fail "the branch's change not used"
}

# [spec-coverage-a0d88a]
test_spec_coverage_a0d88a_an_archived_change_takes_new_proof() {
  setup_e2e
  mkdir -p "$WT/openspec/changes/archive/2026-11-17-7-bbbbbb-y"
  expect_pass bin/e2e --proof --change 7-bbbbbb-y
  [ -f "$WT/openspec/changes/archive/2026-11-17-7-bbbbbb-y/proof/$PROOF_NAME.png" ] || fail 'archived change not used'
}

# [spec-coverage-aa818f]
test_spec_coverage_aa818f_no_change_to_hold_the_proof() {
  setup_e2e
  mkdir -p "$WT/openspec/changes/7-aaaaaa-x" "$WT/openspec/changes/7-bbbbbb-y"
  expect_fail bin/e2e --proof
  expect_output '--change <id>'
  expect_fail bin/e2e --proof --change 9-cccccc-missing
  expect_output '9-cccccc-missing'
  ! grep -q '^create ' "$E2E_TRACE" || fail 'ran before resolving the change'
}

# [spec-coverage-e39d27]
test_spec_coverage_e39d27_proof_options_alone_are_refused() {
  setup_e2e
  local args status
  for args in '--video' '--change x' '--proof --changed' '--changed --proof' '--proof --gates' '--gates --proof' '--proof --change'; do
    status=0
    # shellcheck disable=SC2086 # split on purpose
    OUT="$(bin/e2e $args 2>&1)" || status=$?
    [ "$status" -eq 2 ] || fail "bin/e2e $args exited $status"$'\n'"$OUT"
    expect_output 'usage:'
  done
  ! grep -q '^create ' "$E2E_TRACE" || fail 'ran a refused selection'
}

# [ci-ed7467]
test_ci_ed7467_the_suites_image_uses_the_cache() {
  setup_e2e
  rm "$WT/.env.session"
  expect_pass env FACTORY_BUILD_CACHE=gha bin/e2e --gates
  grep -q '^buildx build --load .*--cache-from type=gha,scope=e2e --cache-to type=gha,mode=max,scope=e2e .*services/e2e$' "$E2E_TRACE" \
    || fail "no cached build: $(cat "$E2E_TRACE")"
  : > "$E2E_TRACE"
  expect_pass bin/e2e --gates
  grep -q '^build -q .*services/e2e$' "$E2E_TRACE" || fail "no plain build: $(cat "$E2E_TRACE")"
  ! grep -q 'type=gha' "$E2E_TRACE" || fail "a cache without the setting: $(cat "$E2E_TRACE")"
  : > "$E2E_TRACE"
  expect_fail env FACTORY_BUILD_CACHE=gh bin/e2e --gates
  expect_output 'FACTORY_BUILD_CACHE'
  [ ! -s "$E2E_TRACE" ] || fail "ran docker with a bad setting: $(cat "$E2E_TRACE")"
}

# A public host that is an IP address cannot be redirected to the forwarders.
test_spec_coverage_746b78_a_public_ip_is_refused() {
  setup_e2e
  local host
  for host in 192.0.2.10 2001:db8::1; do
    session_file "$host"
    expect_fail bin/e2e
    expect_output 'FACTORY_PUBLIC_HOST'
    [ -z "$(create_line)" ] || fail "ran the suite for $host: $(create_line)"
  done
}

# --change names a whole change: a suffix of one is no match.
test_spec_coverage_a0d88a_change_must_name_a_whole_change() {
  setup_e2e
  mkdir -p "$WT/openspec/changes/archive/2026-11-01-7-abcdef-e2e-suite"
  expect_fail bin/e2e --proof --change e2e-suite
  expect_output 'no change e2e-suite'
  [ ! -d "$WT/openspec/changes/archive/2026-11-01-7-abcdef-e2e-suite/proof" ] || fail 'wrote proof into a suffix match'
  expect_pass bin/e2e --proof --change 7-abcdef-e2e-suite
  ls "$WT/openspec/changes/archive/2026-11-01-7-abcdef-e2e-suite/proof/"*.png > /dev/null || fail 'no proof in the named change'
}
