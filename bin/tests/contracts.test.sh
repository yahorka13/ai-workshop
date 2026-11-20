# shellcheck shell=bash disable=SC2154

# A repository with a producer (backend), a consumer (ui) that declares it, a
# consumer (alpha) that sorts before its producer, and a service without a
# contracts:generate script (probe). The fake docker records every call; its
# `start -a` prints the lines in fakes/roots-<service> and its `cp` writes a
# marker file naming the container's service and root.
setup_contracts() {
  mkdir -p "$REPO/bin" "$REPO/fakes" "$REPO/services/probe"
  cp "$BIN/contracts" "$BIN/consumes.sh" "$REPO/bin/"
  local service
  for service in backend ui alpha; do
    mkdir -p "$REPO/services/$service"
    printf '{\n  "scripts": {\n    "contracts:generate": "bun tooling/contracts.ts generate"\n  }\n}\n' > "$REPO/services/$service/package.json"
  done
  printf '{\n  "scripts": {\n    "lint": "eslint ."\n  }\n}\n' > "$REPO/services/probe/package.json"
  mkdir -p "$REPO/services/backend/contracts" "$REPO/services/backend/src/generated" "$REPO/services/ui/src/services/graphql/generated" "$REPO/services/alpha/generated"
  printf 'stale\n' > "$REPO/services/backend/contracts/stale.graphql"
  printf 'stale\n' > "$REPO/services/backend/src/generated/stale.ts"
  printf 'stale\n' > "$REPO/services/ui/src/services/graphql/generated/stale.ts"
  printf 'stale\n' > "$REPO/services/alpha/generated/stale.ts"
  printf '# Producers whose contracts this service reads.\nbackend\n' > "$REPO/services/ui/consumes.txt"
  printf 'backend\n' > "$REPO/services/alpha/consumes.txt"
  printf 'generated: contracts\ngenerated: src/generated\n' > "$REPO/fakes/roots-backend"
  printf 'generated: src/services/graphql/generated\n' > "$REPO/fakes/roots-ui"
  printf 'generated: generated\n' > "$REPO/fakes/roots-alpha"
  export CONTRACTS_TRACE="$REPO/docker-calls"
  export CONTRACTS_FAKES="$REPO/fakes"
  cat > "$REPO/fakes/docker" <<'DOCKER'
#!/usr/bin/env bash
set -eu
printf '%s\n' "$*" >> "$CONTRACTS_TRACE"
service_of() {
  local name="${1#factory-contracts-}"
  printf '%s\n' "${name%-*}"
}
case "$1" in
  build|create|rm|image) ;;
  start)
    service="$(service_of "$3")"
    echo "$service: generating"
    if [ "${FAIL_SERVICE:-}" = "$service" ]; then echo "$service: boom" >&2; exit 1; fi
    cat "$CONTRACTS_FAKES/roots-$service"
    ;;
  cp)
    [ "${FAIL_CP:-}" != 1 ]
    service="$(service_of "${2%%:*}")"
    root="${2#*:/app/}"
    root="${root%/.}"
    mkdir -p "$3"
    printf '%s:%s\n' "$service" "$root" > "$3/from-container"
    ;;
  *) exit 2 ;;
esac
DOCKER
  chmod +x "$REPO/fakes/docker"
  export PATH="$REPO/fakes:$PATH"
}

# The services in the order their generation ran.
generated_order() {
  sed -n 's/^start -a factory-contracts-\(.*\)-[^-]*$/\1/p' "$CONTRACTS_TRACE" | tr '\n' ' '
}

# [contracts-25aef9]
test_contracts_25aef9_help_and_invalid_input_need_no_docker() {
  setup_contracts
  expect_pass "$REPO/bin/contracts" --help
  expect_output "usage: bin/contracts generate"
  expect_output "consumes.txt"
  expect_output "never edited by hand"
  expect_output "bin/check <service>"
  local status=0
  "$REPO/bin/contracts" > "$REPO/out" 2>&1 || status=$?
  [ "$status" = 2 ] || fail "no arguments exited $status"
  grep -q '^usage:' "$REPO/out" || fail "no arguments printed no usage"
  status=0
  "$REPO/bin/contracts" check > "$REPO/out" 2>&1 || status=$?
  [ "$status" = 2 ] || fail "unknown subcommand exited $status"
  grep -q '^usage:' "$REPO/out" || fail "unknown subcommand printed no usage"
  status=0
  "$REPO/bin/contracts" generate extra > "$REPO/out" 2>&1 || status=$?
  [ "$status" = 2 ] || fail "extra argument exited $status"
  [ ! -e "$CONTRACTS_TRACE" ] || fail "help or invalid input invoked Docker"
}

# [contracts-f07555] producers regenerate first, consumers read them.
test_contracts_f07555_producers_regenerate_before_consumers() {
  setup_contracts
  cd "$REPO/services" || exit 1
  expect_pass "$REPO/bin/contracts" generate
  local order
  order="$(generated_order)"
  [ "$order" = "backend alpha ui " ] || fail "wrong order: $order"
  ! grep -q 'factory-contracts-probe-' "$CONTRACTS_TRACE" || fail "ran a service without contracts:generate"
  local physical create
  physical="$(cd "$REPO" && pwd -P)"
  grep -q "^build --target checks -t factory-contracts:backend-[^ ]* $physical/services/backend$" "$CONTRACTS_TRACE" || fail "backend not built from its checks target"
  create="$(grep '^create .*factory-contracts-ui-' "$CONTRACTS_TRACE")"
  [[ "$create" == *" --network none "* ]] || fail "ui ran with network: $create"
  [[ "$create" == *" -v $physical/services/backend/contracts:/contracts/backend:ro "* ]] || fail "backend contracts not mounted read-only: $create"
  [[ "$create" == *" bun run contracts:generate" ]] || fail "ui did not run contracts:generate: $create"
  create="$(grep '^create .*factory-contracts-backend-' "$CONTRACTS_TRACE")"
  [[ "$create" == *" --network none "* ]] || fail "backend ran with network: $create"
  [[ "$create" != *" -v "* ]] || fail "backend mounted contracts it does not declare: $create"
  [ "$(cat "$REPO/services/backend/contracts/from-container")" = backend:contracts ] || fail "backend contracts not copied back"
  [ "$(cat "$REPO/services/backend/src/generated/from-container")" = backend:src/generated ] || fail "backend types not copied back"
  [ "$(cat "$REPO/services/ui/src/services/graphql/generated/from-container")" = ui:src/services/graphql/generated ] || fail "ui types not copied back"
  [ ! -e "$REPO/services/backend/contracts/stale.graphql" ] || fail "stale producer file kept"
  [ ! -e "$REPO/services/ui/src/services/graphql/generated/stale.ts" ] || fail "stale consumer file kept"
  [ ! -e "$REPO/services/ui/contracts" ] || fail "ui received a root it did not report"
  expect_output "backend: contracts src/generated"
  expect_output "ui: src/services/graphql/generated"
  grep -q '^rm -f factory-contracts-ui-' "$CONTRACTS_TRACE" || fail "container not cleaned"
  grep -q '^image rm factory-contracts:ui-' "$CONTRACTS_TRACE" || fail "image not cleaned"
}

# [contracts-bcf2fc] a reported root outside the service is refused.
test_contracts_bcf2fc_roots_outside_the_service_are_refused() {
  setup_contracts
  mkdir -p "$REPO/outside"
  ln -s "$REPO/outside" "$REPO/services/ui/link"
  local root
  for root in ../x /etc src/../../x . src/./generated 'src//generated' link/generated '' 'two words'; do
    printf 'generated: %s\n' "$root" > "$REPO/fakes/roots-ui"
    : > "$CONTRACTS_TRACE"
    expect_fail "$REPO/bin/contracts" generate
    expect_output "ui"
    expect_output "refus"
    ! grep -q '^cp factory-contracts-ui-' "$CONTRACTS_TRACE" || fail "copied for refused root '$root'"
    [ -f "$REPO/services/ui/src/services/graphql/generated/stale.ts" ] || fail "ui changed after refused root '$root'"
    [ -z "$(ls "$REPO/outside")" ] || fail "wrote outside the service for '$root'"
  done
  printf 'generated: src/services/graphql/generated\ngenerated: ../x\n' > "$REPO/fakes/roots-ui"
  expect_fail "$REPO/bin/contracts" generate
  [ -f "$REPO/services/ui/src/services/graphql/generated/stale.ts" ] || fail "valid root copied beside a refused one"
}

# [contracts-bcf2fc] a failing generation names the service and copies nothing back.
test_contracts_bcf2fc_failing_generation_stops_and_copies_nothing() {
  setup_contracts
  export FAIL_SERVICE=ui
  expect_fail "$REPO/bin/contracts" generate
  expect_output "ui: boom"
  expect_output "ui: generation failed"
  ! grep -q '^cp factory-contracts-ui-' "$CONTRACTS_TRACE" || fail "copied back after a failure"
  [ -f "$REPO/services/ui/src/services/graphql/generated/stale.ts" ] || fail "ui changed after a failure"
  grep -q '^rm -f factory-contracts-ui-' "$CONTRACTS_TRACE" || fail "failed container not cleaned"
  export FAIL_SERVICE=backend
  : > "$CONTRACTS_TRACE"
  expect_fail "$REPO/bin/contracts" generate
  expect_output "backend: generation failed"
  [ "$(generated_order)" = "backend " ] || fail "consumers ran after the producer failed"
}

# a failed copy leaves the service's root intact.
test_failed_copy_keeps_the_root() {
  setup_contracts
  export FAIL_CP=1
  expect_fail "$REPO/bin/contracts" generate
  expect_output "backend"
  [ -f "$REPO/services/backend/contracts/stale.graphql" ] || fail "failed copy removed the root"
  [ "$(generated_order)" = "backend " ] || fail "continued after a failed copy"
}

# [contracts-e2f420] producers that declare each other, or a service that
# declares itself, cannot be ordered.
test_contracts_e2f420_cycles_fail_before_docker() {
  setup_contracts
  mkdir -p "$REPO/services/ui/contracts"
  printf 'ui\n' > "$REPO/services/backend/consumes.txt"
  expect_fail "$REPO/bin/contracts" generate
  expect_output "cycle"
  expect_output "backend"
  expect_output "ui"
  [ ! -e "$CONTRACTS_TRACE" ] || fail "a cycle invoked Docker"
  printf 'backend # itself\n' > "$REPO/services/backend/consumes.txt"
  expect_fail "$REPO/bin/contracts" generate
  expect_output "cycle between:"
  [ ! -e "$CONTRACTS_TRACE" ] || fail "a self-declaration invoked Docker"
}

# [contracts-2f43a2] every generation container runs with no network and no
# environment file.
test_contracts_2f43a2_generation_runs_offline() {
  setup_contracts
  expect_pass "$REPO/bin/contracts" generate
  local create count=0
  while IFS= read -r create; do
    count=$((count + 1))
    [[ "$create" == *" --network none "* ]] || fail "a generation container has a network: $create"
    [[ "$create" != *"--env-file"* && "$create" != *" -e "* ]] || fail "a generation container gets an environment: $create"
  done < <(grep '^create ' "$CONTRACTS_TRACE")
  [ "$count" = 3 ] || fail "expected 3 generation containers, saw $count"
}

# a declared producer without contracts/ fails before Docker.
test_undeclarable_producer_fails_before_docker() {
  setup_contracts
  printf 'probe\n' > "$REPO/services/ui/consumes.txt"
  expect_fail "$REPO/bin/contracts" generate
  expect_output "consumes.txt"
  expect_output "probe"
  [ ! -e "$CONTRACTS_TRACE" ] || fail "a bad declaration invoked Docker"
}

test_missing_docker_is_reported() {
  setup_contracts
  mkdir "$REPO/no-docker"
  local tool
  for tool in bash dirname grep sed; do
    ln -s "$(command -v "$tool")" "$REPO/no-docker/$tool"
  done
  expect_fail env PATH="$REPO/no-docker" "$REPO/bin/contracts" generate
  expect_output "Docker"
}

# excluded_with_reason <file> <line number>: the entry on that line belongs to
# a run of entries whose nearest line above is a comment (# or //).
excluded_with_reason() {
  awk -v at="$2" 'NR < at { line[NR] = $0 }
    END {
      for (n = at - 1; n > 0; n--) {
        if (line[n] ~ /^[[:space:]]*(#|\/\/)/) exit 0
        if (line[n] ~ /^[[:space:]]*$/) exit 1
      }
      exit 1
    }' "$1"
}

# expect_excluded <file> <how> <path>: <path> is excluded in <file>, and a
# comment stands above its entry. <how> is prettier (one path per line) or
# glob (a quoted "<path>**" in an ESLint or bunfig list).
expect_excluded() {
  # shellcheck disable=SC2153 # ROOT is the repository, set by bin/tests/run.sh
  local file="$ROOT/services/$1" how="$2" path="$3" at
  case "$how" in
    prettier) at="$(grep -nxF -- "$path" "$file" | head -1 | cut -d: -f1)" ;;
    *) at="$(grep -nF -- "\"$path**\"" "$file" | head -1 | cut -d: -f1)" ;;
  esac
  [ -n "$at" ] || fail "services/$1 does not exclude $path"
  excluded_with_reason "$file" "$at" || fail "services/$1 excludes $path without a comment saying why"
}

# [contracts-5ec35e]: the backend's generated contracts/ are left out of
# formatting and lint, each exclusion with a comment saying why; coverage scans
# only src/, and bunfig.toml says why contracts/ needs no exclusion.
test_contracts_5ec35e_generated_files_are_skipped_with_a_reason() {
  expect_excluded backend/.prettierignore prettier contracts/
  expect_excluded backend/eslint.config.mjs glob contracts/
  grep -qE '^#.*contracts/' "$ROOT/services/backend/bunfig.toml" || fail "services/backend/bunfig.toml does not say why contracts/ is not covered"
}

# [contracts-15fd30]: the ui's generated typed documents are left out of
# formatting, lint and coverage, each exclusion with a comment saying why.
test_contracts_15fd30_ui_generated_types_are_skipped_with_a_reason() {
  expect_excluded ui/.prettierignore prettier src/services/graphql/generated/
  expect_excluded ui/eslint.config.mjs glob src/services/graphql/generated/
  expect_excluded ui/bunfig.toml glob src/services/graphql/generated/
}
