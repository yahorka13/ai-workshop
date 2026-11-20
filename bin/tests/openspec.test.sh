# shellcheck shell=bash disable=SC2154
# bin/openspec and the OpenSpec configuration.

test_openspec_without_node_fails_with_fix() {
  mkdir -p "$REPO/nonode"
  local tool
  for tool in bash env dirname cat sed git; do
    ln -s "$(command -v "$tool")" "$REPO/nonode/$tool"
  done
  OUT="$(PATH="$REPO/nonode" "$BIN/openspec" --version 2>&1)" && fail "expected failure: $OUT"
  expect_output "Node 24"
}

# fake_node <version> [<npx-script>]: a node printing <version> and an npx
# running <npx-script> (default: log its arguments to npx.log), first on PATH.
fake_node() {
  mkdir -p fake-bin
  printf '#!/usr/bin/env bash\necho %s\n' "$1" > fake-bin/node
  printf '#!/usr/bin/env bash\n%s\n' "${2:-echo \"\$*\" >> \"$REPO/npx.log\"}" > fake-bin/npx
  chmod +x fake-bin/node fake-bin/npx
  : > npx.log
  PATH="$PWD/fake-bin:$PATH"
}

# [agent-workflow-3015b0]
test_old_node_is_refused_with_fix() {
  fake_node v18.19.0
  expect_fail "$BIN/openspec" --version
  expect_output "v18.19.0"
  expect_output "Node 24"
  [ ! -s npx.log ] || fail "npx ran: $(cat npx.log)"
}

test_node_24_and_later_pass() {
  fake_node v24.0.0
  expect_pass "$BIN/openspec" --version
  grep -q -- '--version' npx.log || fail "npx did not run"
  fake_node v25.1.0
  expect_pass "$BIN/openspec" --version
  grep -q -- '--version' npx.log || fail "npx did not run"
}

# [agent-workflow-eea1e6]
test_profile_note_is_hidden() {
  # shellcheck disable=SC2016 # the fake npx prints literal backticks
  fake_node v24.0.0 'echo Updated.; echo "Note: Your custom profile is missing 3 core workflows: propose, explore, update"; echo "Run \`openspec config profile\` to add them, or \`openspec config profile core\` to use the core set."'
  expect_pass "$BIN/openspec" update
  [ "$OUT" = Updated. ] || fail "expected only Updated., got: $OUT"
}

test_coloured_profile_note_is_hidden() {
  fake_node v24.0.0 'echo Updated.; printf "\\033[2mNote: Your custom profile is missing 3 core workflows\\033[22m\\n"'
  expect_pass "$BIN/openspec" update
  [ "$OUT" = Updated. ] || fail "expected only Updated., got: $OUT"
}

test_update_keeps_the_exit_status() {
  fake_node v24.0.0 'echo failing; exit 3'
  local status=0
  OUT="$("$BIN/openspec" update 2>&1)" || status=$?
  [ "$status" -eq 3 ] || fail "expected exit 3, got $status: $OUT"
  expect_output failing
}

test_config_names_the_factory_schema() {
  grep -qx 'schema: factory' "$ROOT/openspec/config.yaml" || fail "config.yaml does not use schema: factory"
  grep -qx 'name: factory' "$ROOT/openspec/schemas/factory/schema.yaml" || fail "the schema is not named factory"
}

test_config_takes_hash_scenario_ids_only() {
  ! grep -q 'retired_capabilities' "$ROOT/openspec/config.yaml" || fail "config.yaml keeps retired capabilities"
  ! grep -qi 'numeric' "$ROOT/openspec/config.yaml" || fail "config.yaml still allows numeric IDs"
}
