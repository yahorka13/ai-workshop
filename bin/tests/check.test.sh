# shellcheck shell=bash disable=SC2154

setup_check() {
  mkdir -p "$REPO/bin" "$REPO/services/reference" "$REPO/fakes"
  cp "$BIN/check" "$BIN/consumes.sh" "$BIN/factory-jobs.sh" "$REPO/bin/"
  touch "$REPO/services/reference/package.json" "$REPO/services/reference/Dockerfile"
  unset FACTORY_JOBS
  export FACTORY_ENV_FILE="$REPO/env"
  printf '#!/bin/sh\necho 6\n' > "$REPO/fakes/nproc"
  printf '#!/bin/sh\necho 6\n' > "$REPO/fakes/sysctl"
  chmod +x "$REPO/fakes/nproc" "$REPO/fakes/sysctl"
  export CHECK_TRACE="$REPO/docker-calls"
  export CHECK_REPO="$REPO"
  cat > "$REPO/fakes/docker" <<'DOCKER'
#!/usr/bin/env bash
set -eu
printf '%s\n' "$*" >> "$CHECK_TRACE"
# FAIL_SERVICE limits FAIL_PHASE and FAIL_GATES to that service's calls.
if [ -n "${FAIL_SERVICE:-}" ] && [[ "$*" != *"services/$FAIL_SERVICE"* ]] && [[ "$*" != *"factory-check-$FAIL_SERVICE-"* ]]; then
  FAIL_PHASE="" FAIL_GATES=""
fi
case "$1" in
  build) [ "${FAIL_PHASE:-}" != build ] ;;
  create) [ "${FAIL_PHASE:-}" != create ] ;;
  start) [ "${FAIL_PHASE:-}" != start ] ;;
  exec)
    gate="${5:-}"
    printf 'start %s\n' "$gate" >> "$CHECK_TRACE"
    sleep "${GATE_SLEEP:-0}"
    printf 'end %s\n' "$gate" >> "$CHECK_TRACE"
    printf 'out %s\n' "$gate"
    case ",${NETWORK_NOISE:-}," in *",$gate,"*) printf 'ENETUNREACH\n' ;; esac
    case ",${NETWORK_GATES:-}," in *",$gate,"*) printf 'error: getaddrinfo EAI_AGAIN example.com\n'; exit 1 ;; esac
    if [ "${PARTIAL_LINE:-}" = 1 ]; then printf 'tail'; fi
    [ "${FAIL_PHASE:-}" != "$gate" ]
    case ",${FAIL_GATES:-}," in *",$gate,"*) exit 1 ;; esac
    if [ "${BLOCK_ARTIFACTS:-}" = 1 ] && [ "$gate" = coverage ]; then
      printf 'blocked\n' > "$CHECK_REPO/tmp/check/reference/${2#factory-check-reference-}/coverage"
    fi
    if [ -n "${HOLD_GATE:-}" ]; then sleep 1; fi
    ;;
  cp)
    [ "${FAIL_PHASE:-}" != artifacts ]
    mkdir -p "$3"
    printf 'coverage\n' > "$3/lcov.info"
    ;;
  rm|image) [ "${FAIL_PHASE:-}" != cleanup ] ;;
  *) exit 2 ;;
esac
DOCKER
  chmod +x "$REPO/fakes/docker"
  export PATH="$REPO/fakes:$PATH"
}

# [service-checks-6ccbef] [service-checks-086fa5]
test_service_checks_086fa5_help_and_invalid_names_need_no_docker() {
  setup_check
  expect_pass "$REPO/bin/check" --help
  expect_output "usage:"
  expect_output "Docker"
  expect_output "run contracts first, then"
  expect_output "consumes.txt"
  expect_output "--gates"
  expect_output "duplicates"
  expect_output "unused"
  expect_output "imports"
  expect_output "--all"
  expect_output "tmp/check/"
  expect_output "FACTORY_JOBS"
  expect_output "line in ~/.factory/env"
  expect_output "no network"
  local name
  for name in unknown ../reference --option 'reference/../reference'; do
    expect_fail "$REPO/bin/check" "$name"
  done
  expect_fail "$REPO/bin/check"
  expect_fail "$REPO/bin/check" reference reference
  expect_output "reference"
  expect_fail "$REPO/bin/check" --all reference
  expect_output "--all"
  expect_fail "$REPO/bin/check" --all --all
  mkdir "$REPO/outside"
  touch "$REPO/outside/package.json" "$REPO/outside/Dockerfile"
  ln -s "$REPO/outside" "$REPO/services/escape"
  expect_fail "$REPO/bin/check" escape
  [ ! -e "$CHECK_TRACE" ] || fail "invalid input invoked Docker"
}

test_service_checks_a4a0e9_runs_all_gates_from_another_directory() {
  setup_check
  cd "$REPO/services" || exit 1
  expect_pass "$REPO/bin/check" reference
  expect_output "Check artifacts:"
  [ "$(gates_run | sort | tr '\n' ' ')" = "contracts coverage duplicates imports lint typecheck unused " ] || fail "wrong gates: $(gates_run)"
  find "$REPO/tmp/check/reference" -name lcov.info | grep -q . || fail "missing artifacts"
  grep -q '^rm -f factory-check-' "$CHECK_TRACE" || fail "container not cleaned"
  grep -q '^image rm factory-check:' "$CHECK_TRACE" || fail "image not cleaned"
}

# [service-checks-4d1428] [service-checks-247a01]
test_service_checks_4d1428_build_failure_stops_and_gate_failures_are_named() {
  setup_check
  local phase
  for phase in build create start contracts lint typecheck coverage duplicates unused imports; do
    export FAIL_PHASE="$phase"
    : > "$CHECK_TRACE"
    expect_fail "$REPO/bin/check" reference
    expect_output "reference: $phase"
    case "$phase" in
      build|create|start)
        ! grep -q '^exec ' "$CHECK_TRACE" || fail "$phase failure ran a gate" ;;
      contracts)
        [ "$(gates_run)" = contracts ] || fail "contracts failure ran $(gates_run)"
        expect_output "reference: contracts failed; see " ;;
      *)
        [ "$(grep -c '^end ' "$CHECK_TRACE")" = 7 ] || fail "$phase failure stopped another gate"
        expect_output "reference: $phase failed; see " ;;
    esac
  done
}

# The gates bin/check ran, in order, one per line.
gates_run() {
  sed -n 's/^exec .* bun run //p' "$CHECK_TRACE"
}

# [service-checks-680c1f]: the duplicates gate can run alone.
test_service_checks_680c1f_duplicates_runs_alone() {
  setup_check
  expect_pass "$REPO/bin/check" reference --gates duplicates
  [ "$(gates_run)" = duplicates ] || fail "wrong gates: $(gates_run)"
  [ -z "$(find "$REPO/tmp/check/reference" -name lcov.info)" ] || fail "collected coverage without the coverage gate"
}

# [service-checks-680c1f]: the unused gate can run alone.
test_service_checks_680c1f_unused_runs_alone() {
  setup_check
  expect_pass "$REPO/bin/check" reference --gates unused
  [ "$(gates_run)" = unused ] || fail "wrong gates: $(gates_run)"
}

# [service-checks-680c1f]: the imports gate can run alone.
test_service_checks_680c1f_imports_runs_alone() {
  setup_check
  expect_pass "$REPO/bin/check" reference --gates imports
  [ "$(gates_run)" = imports ] || fail "wrong gates: $(gates_run)"
}

# [service-checks-680c1f]: only the selected gates run, in canonical order.
test_service_checks_680c1f_selected_gates_run_alone() {
  setup_check
  expect_pass "$REPO/bin/check" reference --gates typecheck,lint
  [ "$(gates_run | sort | tr '\n' ' ')" = "lint typecheck " ] || fail "wrong gates: $(gates_run)"
  ! grep -q '^cp ' "$CHECK_TRACE" || fail "collected coverage artifacts without coverage"
  ! find "$REPO/tmp/check/reference" -name lcov.info | grep -q . || fail "artifacts without coverage"
  grep -q '^image rm factory-check:' "$CHECK_TRACE" || fail "image not cleaned"
}

test_service_checks_680c1f_gates_before_the_service() {
  setup_check
  expect_pass "$REPO/bin/check" --gates lint reference
  [ "$(gates_run)" = lint ] || fail "wrong gates: $(gates_run)"
}

test_service_checks_680c1f_duplicate_gate_runs_once() {
  setup_check
  expect_pass "$REPO/bin/check" reference --gates typecheck,typecheck
  [ "$(gates_run)" = typecheck ] || fail "wrong gates: $(gates_run)"
}

test_service_checks_680c1f_selected_gate_failure_is_named() {
  setup_check
  export FAIL_GATES=lint
  expect_fail "$REPO/bin/check" reference --gates lint,typecheck
  expect_output "reference: lint failed"
  [ "$(gates_run | sort | tr '\n' ' ')" = "lint typecheck " ] || fail "wrong gates: $(gates_run)"
}

test_service_checks_680c1f_coverage_selected_keeps_artifacts() {
  setup_check
  expect_pass "$REPO/bin/check" reference --gates coverage
  [ "$(gates_run)" = coverage ] || fail "wrong gates: $(gates_run)"
  expect_output "Check artifacts:"
  find "$REPO/tmp/check/reference" -name lcov.info | grep -q . || fail "missing artifacts"
}

# [service-checks-a10223]: a bad selection exits with usage before Docker.
test_service_checks_a10223_invalid_gate_selection_is_local() {
  setup_check
  local status
  for args in "--gates nosuch" "--gates ," "--gates contracts," "--gates" "--gates lint --gates typecheck" "--gates coverage,Lint"; do
    status=0
    # shellcheck disable=SC2086 # one word per argument
    OUT="$("$REPO/bin/check" reference $args 2>&1)" || status=$?
    [ "$status" = 2 ] || fail "'$args' exited $status: $OUT"
    expect_output "contracts, lint, typecheck, coverage"
  done
  status=0
  OUT="$("$REPO/bin/check" reference --gates '' 2>&1)" || status=$?
  [ "$status" = 2 ] || fail "an empty selection exited $status: $OUT"
  [ ! -e "$CHECK_TRACE" ] || fail "an invalid selection invoked Docker"
}

# [service-checks-df8cd7]: the coverage gate is the test run.
test_service_checks_df8cd7_each_suite_runs_once_per_check() {
  setup_check
  cd "$REPO/services" || exit 1
  expect_pass "$REPO/bin/check" reference
  ! grep -qE ' bun run test:(unit|integration)$' "$CHECK_TRACE" || fail "a suite runs as its own phase"
  [ "$(grep -c ' bun run coverage$' "$CHECK_TRACE")" = 1 ] || fail "coverage did not run exactly once"
  export FAIL_PHASE=coverage
  expect_fail "$REPO/bin/check" reference
  expect_output "reference: coverage"
}

# [service-checks-28396e]
test_service_checks_28396e_artifact_and_cleanup_failures_are_visible() {
  setup_check
  export FAIL_PHASE=artifacts
  expect_fail "$REPO/bin/check" reference
  expect_output "reference: artifacts"
  grep -q '^rm ' "$CHECK_TRACE" || fail "failed copy skipped cleanup"
  export FAIL_PHASE=cleanup
  expect_fail "$REPO/bin/check" reference
  expect_output "cleanup"
}

test_service_checks_28396e_unusable_artifact_directory_names_the_phase() {
  setup_check
  export BLOCK_ARTIFACTS=1
  expect_fail "$REPO/bin/check" reference
  expect_output "reference: artifacts failed"
  grep -q '^rm ' "$CHECK_TRACE" || fail "artifact directory failure skipped cleanup"
}

# [service-checks-e7ab77]
test_service_checks_e7ab77_overlapping_checks_have_distinct_resources() {
  setup_check
  "$REPO/bin/check" reference > "$REPO/first.log" 2>&1 &
  local first=$!
  "$REPO/bin/check" reference > "$REPO/second.log" 2>&1 &
  local second=$!
  wait "$first" || fail "first invocation failed"
  wait "$second" || fail "second invocation failed"
  [ "$(grep '^create ' "$CHECK_TRACE" | sort -u | wc -l | tr -d ' ')" = 2 ] || fail "container identities overlap"
  [ "$(find "$REPO/tmp/check/reference" -name lcov.info | wc -l | tr -d ' ')" = 2 ] || fail "artifacts overlap"
}

test_service_checks_e7ab77_signal_cleans_only_owned_resources() {
  setup_check
  export HOLD_GATE=1
  "$REPO/bin/check" reference > "$REPO/signal.log" 2>&1 &
  local child=$! attempt=0
  while [ "$attempt" -lt 100 ]; do
    attempt=$((attempt + 1))
    if [ -f "$CHECK_TRACE" ] && grep -q '^exec ' "$CHECK_TRACE"; then break; fi
    sleep 0.02
  done
  kill -TERM "$child"
  if wait "$child"; then fail "terminated invocation passed"; fi
  grep -q '^rm -f factory-check-' "$CHECK_TRACE" || fail "signal leaked container"
  grep -q '^image rm factory-check:' "$CHECK_TRACE" || fail "signal leaked image"
}

test_service_checks_a4a0e9_paths_with_spaces_are_preserved() {
  setup_check
  mkdir -p "$REPO/space path"
  mv "$REPO/bin" "$REPO/services" "$REPO/space path/"
  expect_pass "$REPO/space path/bin/check" reference
  local physical
  physical="$(cd "$REPO/space path" && pwd -P)"
  expect_output "Check artifacts: $physical/tmp/check/reference/"
}


test_service_checks_247a01_missing_docker_has_a_build_diagnostic() {
  setup_check
  mkdir "$REPO/no-docker"
  ln -s "$(command -v bash)" "$REPO/no-docker/bash"
  ln -s "$(command -v dirname)" "$REPO/no-docker/dirname"
  expect_fail env PATH="$REPO/no-docker" "$REPO/bin/check" reference
  expect_output "reference: build failed: Docker"
}

# The FACTORY_JOBS value bin/check passed to its container.
container_jobs() {
  sed -n 's/^create .* -e FACTORY_JOBS=\([^ ]*\) .*/\1/p' "$CHECK_TRACE"
}

# [service-checks-60d1b5]: with nothing set, every core is used.
test_service_checks_60d1b5_unset_jobs_uses_every_core() {
  setup_check
  expect_pass "$REPO/bin/check" reference
  [ "$(container_jobs)" = 6 ] || fail "wrong jobs: $(container_jobs)"
}

# [service-checks-f382dc]: the machine env file caps the jobs; an export wins.
test_service_checks_f382dc_env_file_caps_and_export_wins() {
  setup_check
  printf 'OTHER=1\nFACTORY_JOBS=2\n' > "$REPO/env"
  chmod 600 "$REPO/env"
  expect_pass "$REPO/bin/check" reference
  [ "$(container_jobs)" = 2 ] || fail "env file ignored: $(container_jobs)"
  printf 'FACTORY_JOBS="4"\n' > "$REPO/env"
  : > "$CHECK_TRACE"
  expect_pass "$REPO/bin/check" reference
  [ "$(container_jobs)" = 4 ] || fail "quoted value ignored: $(container_jobs)"
  : > "$CHECK_TRACE"
  expect_pass env FACTORY_JOBS=3 "$REPO/bin/check" reference
  [ "$(container_jobs)" = 3 ] || fail "export did not win: $(container_jobs)"
}

test_service_checks_f382dc_shared_env_file_is_refused() {
  setup_check
  printf 'FACTORY_JOBS=2\n' > "$REPO/env"
  chmod 644 "$REPO/env"
  expect_fail "$REPO/bin/check" reference
  expect_output "chmod 600"
  [ ! -e "$CHECK_TRACE" ] || fail "a shared env file invoked Docker"
}

# [service-checks-ea3bad]: a job count that is not a positive integer is local.
test_service_checks_ea3bad_invalid_jobs_are_local() {
  setup_check
  local jobs status
  for jobs in 0 -1 abc 2.5 01; do
    status=0
    OUT="$(FACTORY_JOBS="$jobs" "$REPO/bin/check" reference 2>&1)" || status=$?
    [ "$status" = 2 ] || fail "FACTORY_JOBS=$jobs exited $status: $OUT"
    expect_output "FACTORY_JOBS"
    expect_output "positive integer"
  done
  [ ! -e "$CHECK_TRACE" ] || fail "an invalid job count invoked Docker"
}

# The fake gates' start and end lines, without docker's own start command.
gate_events() {
  grep -E '^(start|end) (contracts|lint|typecheck|coverage|duplicates|unused|imports)$' "$CHECK_TRACE" || true
}

# [service-checks-a4a0e9]: the gates run together.
test_service_checks_a4a0e9_gates_run_together() {
  setup_check
  export GATE_SLEEP=0.3
  expect_pass "$REPO/bin/check" reference
  local events
  events="$(gate_events | tr '\n' ' ')"
  [[ "${events#start contracts end contracts }" =~ ^(start (lint|typecheck|coverage|duplicates|unused|imports) ){6}end ]] || fail "gates did not overlap: $events"
}

# [service-checks-39fb15]: contracts ends before the other gates start.
test_service_checks_39fb15_contracts_first_then_the_rest_together() {
  setup_check
  export GATE_SLEEP=0.2
  expect_pass "$REPO/bin/check" reference
  local events
  events="$(gate_events | tr '\n' ' ')"
  [[ "$events" == "start contracts end contracts start "* ]] || fail "contracts did not finish first: $events"
}

# [service-checks-31b834]: a failed contracts gate stops the check before the others.
test_service_checks_31b834_contracts_failure_stops_before_the_others() {
  setup_check
  export FAIL_PHASE=contracts
  expect_fail "$REPO/bin/check" reference
  expect_output "reference: contracts failed; see "
  expect_output "contracts.log"
  [ "$(gates_run)" = contracts ] || fail "contracts failure ran $(gates_run)"
  export FAIL_PHASE=contracts
  expect_fail "$REPO/bin/check" reference --gates contracts,typecheck
  [ "$(gates_run | tail -n 1)" = contracts ] || fail "ran after a failed contracts gate"
}

# [contracts-9289fc]: declared producers' contracts are mounted read-only.
test_contracts_9289fc_declared_contracts_are_mounted_read_only() {
  setup_check
  expect_pass "$REPO/bin/check" reference
  ! grep '^create ' "$CHECK_TRACE" | grep -q -- ' -v ' || fail "mounted contracts without consumes.txt"
  mkdir -p "$REPO/services/backend/contracts" "$REPO/services/other/contracts"
  printf '# Producers whose contracts this service reads.\n\n  backend  \n# other\nother # inline comment' > "$REPO/services/reference/consumes.txt"
  : > "$CHECK_TRACE"
  expect_pass "$REPO/bin/check" reference
  local physical create
  physical="$(cd "$REPO" && pwd -P)"
  create="$(grep '^create ' "$CHECK_TRACE")"
  [[ "$create" == *" -v $physical/services/backend/contracts:/contracts/backend:ro "* ]] || fail "backend not mounted read-only: $create"
  [[ "$create" == *" -v $physical/services/other/contracts:/contracts/other:ro "* ]] || fail "last line without newline not mounted: $create"
  [ "$(grep -o ' -v ' <<< "$create" | wc -l | tr -d ' ')" = 2 ] || fail "wrong mounts: $create"
}

# [contracts-d55f7d]: a bad declaration fails before any Docker call.
test_contracts_d55f7d_unknown_producer_fails_before_docker() {
  setup_check
  mkdir -p "$REPO/services/nocontracts" "$REPO/outside/contracts"
  ln -s "$REPO/outside" "$REPO/services/escape"
  mkdir -p "$REPO/services/linked"
  ln -s "$REPO/outside/contracts" "$REPO/services/linked/contracts"
  local name
  for name in nosuch nocontracts escape linked Bad_Name ../outside 'two names'; do
    printf '%s\n' "$name" > "$REPO/services/reference/consumes.txt"
    expect_fail "$REPO/bin/check" reference
    expect_output "reference"
    expect_output "$name"
    expect_output "consumes.txt"
    [ ! -e "$CHECK_TRACE" ] || fail "bad declaration '$name' invoked Docker"
  done
}

# The run directory of the only check in this test, as bin/check prints it.
run_dir() {
  find "$(cd "$REPO" && pwd -P)/tmp/check/reference" -mindepth 1 -maxdepth 1 -type d -name 'run.*'
}

# [service-checks-58493f]: every line names its gate and each gate keeps its own log.
test_service_checks_58493f_every_line_names_its_gate() {
  setup_check
  expect_pass "$REPO/bin/check" reference
  local gate
  for gate in lint typecheck coverage duplicates unused imports; do
    expect_output "reference/$gate | out $gate"
    [ "$(cat "$(run_dir)/$gate.log")" = "out $gate" ] || fail "$gate.log: $(cat "$(run_dir)/$gate.log")"
  done
  grep -q '^reference/lint | out lint$' "$(run_dir)/check.log" || fail "check.log lost the prefixed stream"
}

test_service_checks_58493f_partial_last_line_is_kept() {
  setup_check
  export PARTIAL_LINE=1
  expect_pass "$REPO/bin/check" reference
  expect_output "reference/lint | tail"
  [ "$(tail -n 1 "$(run_dir)/lint.log")" = tail ] || fail "lint.log lost its last line"
}

# [service-checks-247a01]: a failed gate lets the others finish and every failure is named.
test_service_checks_247a01_failed_gates_do_not_stop_the_others() {
  setup_check
  export FAIL_GATES=lint,typecheck GATE_SLEEP=0.2
  expect_fail "$REPO/bin/check" reference
  expect_output "reference: lint failed; see $(run_dir)/lint.log"
  expect_output "reference: typecheck failed; see $(run_dir)/typecheck.log"
  grep -q '^end coverage$' "$CHECK_TRACE" || fail "coverage was stopped"
  ! grep -q '^cp ' "$CHECK_TRACE" || fail "collected artifacts after a failure"
  grep -q '^rm -f factory-check-' "$CHECK_TRACE" || fail "container not cleaned"
}

test_service_checks_247a01_failed_coverage_collects_no_artifacts() {
  setup_check
  export FAIL_GATES=coverage
  expect_fail "$REPO/bin/check" reference
  expect_output "reference: coverage failed; see "
  ! grep -q '^cp ' "$CHECK_TRACE" || fail "collected artifacts from a failed coverage gate"
}

# [service-checks-247a01]: a failure points at a log that holds the gate's output.
test_service_checks_247a01_failure_points_at_its_log() {
  setup_check
  export FAIL_GATES=typecheck
  expect_fail "$REPO/bin/check" reference
  local log
  log="$(sed -n 's/^reference: typecheck failed; see //p' <<< "$OUT")"
  [ "$(cat "$log")" = "out typecheck" ] || fail "the named log does not hold the gate's output: $log"
}

# Interrupting concurrent gates leaves no gate process behind.
test_service_checks_e7ab77_signal_stops_every_gate() {
  setup_check
  export GATE_SLEEP=5
  "$REPO/bin/check" reference > "$REPO/signal.log" 2>&1 &
  local child=$! attempt=0
  while [ "$attempt" -lt 200 ]; do
    attempt=$((attempt + 1))
    if [ -f "$CHECK_TRACE" ] && [ "$(gate_events | grep -c '^start ')" = 7 ]; then break; fi
    sleep 0.05
  done
  [ "$attempt" -lt 200 ] || fail "gates never started together"
  kill -TERM "$child"
  if wait "$child"; then fail "terminated invocation passed"; fi
  sleep 0.2
  ! pgrep -f "$REPO/fakes/docker exec" > /dev/null || fail "a gate process survived the interruption"
  grep -q '^rm -f factory-check-' "$CHECK_TRACE" || fail "signal leaked container"
}

# A second service beside reference, and one with no checks target.
add_services() {
  mkdir -p "$REPO/services/other" "$REPO/services/plain"
  touch "$REPO/services/other/package.json" "$REPO/services/plain/package.json"
  printf 'FROM oven/bun AS base\nFROM base AS checks\n' > "$REPO/services/reference/Dockerfile"
  cp "$REPO/services/reference/Dockerfile" "$REPO/services/other/Dockerfile"
  printf 'FROM oven/bun\n' > "$REPO/services/plain/Dockerfile"
}

# The result lines of a run of several services, in order.
results() {
  grep -E '^[a-z-]+: (passed|failed)$' <<< "$OUT" | tr '\n' ' '
}

# [service-checks-bc70aa] [service-checks-78a9b1]: named services run together and share the jobs.
test_service_checks_bc70aa_named_services_run_together() {
  setup_check
  add_services
  export GATE_SLEEP=0.3
  expect_pass env FACTORY_JOBS=8 "$REPO/bin/check" reference other
  [ "$(results)" = "reference: passed other: passed " ] || fail "wrong results: $(results)"
  [ "$(grep -c '^create .* -e FACTORY_JOBS=4 ' "$CHECK_TRACE")" = 2 ] || fail "jobs not split: $(grep '^create' "$CHECK_TRACE")"
  local events
  events="$(gate_events | tr '\n' ' ')"
  [[ "$events" =~ ^start\ contracts\ start\ contracts ]] || fail "services did not start together: $events"
  expect_output "reference/lint | out lint"
  expect_output "other/lint | out lint"
}

test_service_checks_bc70aa_jobs_never_drop_to_zero() {
  setup_check
  add_services
  expect_pass env FACTORY_JOBS=2 "$REPO/bin/check" reference other plain
  [ "$(grep -c '^create .* -e FACTORY_JOBS=1 ' "$CHECK_TRACE")" = 3 ] || fail "a service got no job: $(grep '^create' "$CHECK_TRACE")"
}

test_service_checks_bc70aa_result_lines_follow_given_order() {
  setup_check
  add_services
  expect_pass "$REPO/bin/check" other reference --gates lint
  [ "$(results)" = "other: passed reference: passed " ] || fail "wrong order: $(results)"
  [ "$(gates_run)" = $'lint\nlint' ] || fail "--gates not passed on: $(gates_run)"
}

# [service-checks-28e346]: a failed service fails the run, the others finish.
test_service_checks_28e346_one_failed_service_fails_the_run() {
  setup_check
  add_services
  local phase
  for phase in lint build; do
    : > "$CHECK_TRACE"
    export FAIL_SERVICE=other FAIL_PHASE="$phase"
    expect_fail "$REPO/bin/check" reference other
    [ "$(results)" = "reference: passed other: failed " ] || fail "$phase: wrong results: $(results)"
    expect_output "other: $phase failed"
    grep -q '^exec factory-check-reference-.* bun run coverage$' "$CHECK_TRACE" || fail "$phase: reference did not finish"
  done
}

# [service-checks-f54ace]: --all checks every service with a checks target.
test_service_checks_f54ace_all_checks_services_with_a_checks_target() {
  setup_check
  add_services
  expect_pass "$REPO/bin/check" --all --gates lint
  [ "$(results)" = "other: passed reference: passed " ] || fail "wrong services: $(results)"
  ! grep -q 'services/plain' "$CHECK_TRACE" || fail "checked a service without a checks target"
  rm "$REPO/services/other/Dockerfile" "$REPO/services/reference/Dockerfile"
  touch "$REPO/services/other/Dockerfile" "$REPO/services/reference/Dockerfile"
  : > "$CHECK_TRACE"
  local status=0
  OUT="$("$REPO/bin/check" --all 2>&1)" || status=$?
  [ "$status" = 2 ] || fail "--all with no checks target exited $status: $OUT"
  expect_output "--all"
  [ ! -s "$CHECK_TRACE" ] || fail "--all with nothing to check invoked Docker"
}

# Interrupting several services stops every one and each cleans up.
test_check_signal_stops_every_service() {
  setup_check
  add_services
  export GATE_SLEEP=5
  "$REPO/bin/check" reference other > "$REPO/signal.log" 2>&1 &
  local child=$! attempt=0
  while [ "$attempt" -lt 200 ]; do
    attempt=$((attempt + 1))
    if [ -f "$CHECK_TRACE" ] && [ "$(gate_events | grep -c "^start ")" -ge 8 ]; then break; fi
    sleep 0.05
  done
  [ "$attempt" -lt 200 ] || fail "services never started"
  kill -TERM "$child"
  if wait "$child"; then fail "terminated run passed"; fi
  sleep 0.3
  ! pgrep -f "$REPO/fakes/docker exec" > /dev/null || fail "a gate process survived"
  [ "$(grep -c '^rm -f factory-check-' "$CHECK_TRACE")" = 2 ] || fail "a container leaked"
  [ "$(grep -c '^image rm factory-check:' "$CHECK_TRACE")" = 2 ] || fail "an image leaked"
}

# [service-checks-172a37]
test_service_checks_172a37_gates_run_with_no_network() {
  setup_check
  expect_pass "$REPO/bin/check" reference
  grep -q '^create .*--network none' "$CHECK_TRACE" || fail "container has a network"
  ! grep -q '^build .*--network' "$CHECK_TRACE" || fail "build lost its network"
  [[ "$OUT" != *"tried to reach the network"* ]] || fail "hint without a network failure"
}

# [service-checks-5ed7ca]
test_service_checks_5ed7ca_network_failure_names_the_reason() {
  setup_check
  export NETWORK_GATES=coverage,lint
  expect_fail "$REPO/bin/check" reference
  expect_output "reference: coverage failed; see "
  expect_output "reference: coverage tried to reach the network; checks run with no network on purpose: fake the provider at its contract"
  expect_output "reference: lint tried to reach the network;"
}

test_service_checks_5ed7ca_passing_gate_with_network_noise_gets_no_hint() {
  setup_check
  export NETWORK_NOISE=coverage FAIL_GATES=lint
  expect_fail "$REPO/bin/check" reference
  [[ "$OUT" != *"tried to reach the network"* ]] || fail "hint for a passing gate"
}

test_service_checks_5ed7ca_other_failure_gets_no_hint() {
  setup_check
  export FAIL_GATES=coverage
  expect_fail "$REPO/bin/check" reference
  [[ "$OUT" != *"tried to reach the network"* ]] || fail "hint without a network error"
}
