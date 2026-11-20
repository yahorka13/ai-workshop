# shellcheck shell=bash disable=SC2154,SC2034,SC2016
# Orca hook tests. The workspace's own bin/setup, bin/up and bin/down are stubs that
# log to $LOG, except where a test copies the real session scripts. bin/session is
# the real one; bin/compose is a stub whose watch sleeps and whose config lists the
# services in $STUBS/services (postgres when absent).
orca_fixture() {
  WT="$REPO/work tree"
  STUBS="$REPO/stubs"
  LOG="$REPO/calls.log"
  rm -rf "$WT" "$STUBS" "$LOG"
  mkdir -p "$WT/bin" "$STUBS" "$REPO/home"
  cp "$ROOT/bin/orca-setup" "$ROOT/bin/orca-archive" "$ROOT/bin/orca-autostart" "$REPO/"
  local name
  for name in setup up down; do
    printf '#!/bin/bash\necho "%s $PWD" >> "%s"\n[ ! -f "%s/%s-fails" ] || { echo "%s failed" >&2; exit 3; }\n' \
      "$name" "$LOG" "$STUBS" "$name" "$name" > "$WT/bin/$name"
    chmod +x "$WT/bin/$name"
  done
  # The stub bin/orca-autostart records its directory, whether it survives a
  # hangup and any stdin, prints to stdout and, with autostart-hold, waits for
  # autostart-go before saying it is done.
  cat > "$WT/bin/orca-autostart" <<STUB
#!/bin/bash
S="$STUBS"
STUB
  cat >> "$WT/bin/orca-autostart" <<'STUB'
{
  echo "dir $PWD"
  kill -HUP $$
  echo 'survived hangup'
  if read -r -t 1 LINE; then echo "stdin $LINE"; fi
} > "$S/autostart.tmp"
mv "$S/autostart.tmp" "$S/autostart.seen"
echo AUTOSTART-STDOUT
if [ -f "$S/autostart-hold" ]; then
  for _ in $(seq 50); do [ ! -f "$S/autostart-go" ] || break; sleep 0.1; done
fi
touch "$S/autostart.done"
STUB
  chmod +x "$WT/bin/orca-autostart"
  cp "$ROOT/bin/session" "$WT/bin/session"
  export FACTORY_SESSION_REGISTRY="$REPO/registry"
  compose_stub "$WT/bin/compose"
  # The stub bin/up writes the session file the real one would.
  printf 'printf "FACTORY_SESSION_ID=2\\nFACTORY_PORT_UI=11100\\nFACTORY_PORT_POSTGRES=11102\\nFACTORY_PUBLIC_HOST=127.0.0.1\\n" > "%s/.env.session"\n' "$WT" >> "$WT/bin/up"
  # The orca stub logs every call next to the stubs directory, so it still
  # finds the log when a test moves it, and answers terminal list and read
  # from files: read-<handle>.first once, then read-<handle>.json.
  cat > "$STUBS/orca" <<'STUB'
#!/bin/bash
S="$(cd "$(dirname "$0")" && pwd)"
echo "orca $*" >> "$S/../calls.log"
[ ! -f "$S/orca-fails" ] || exit 4
case "$1 $2" in
  'terminal list') cat "$S/list.json" ;;
  'terminal read')
    if [ -f "$S/read-$4.first" ]; then cat "$S/read-$4.first"; rm "$S/read-$4.first"; else cat "$S/read-$4.json"; fi ;;
esac
STUB
  chmod +x "$STUBS/orca"
  # This repository is my.org/my-app: a dot and a dash that a pattern must take literally.
  git -C "$WT" init -q
  git -C "$WT" remote add origin https://github.com/my.org/my-app.git
  cp "$ROOT/bin/repo" "$WT/bin/repo"
  printf 'postgres\nui\n' > "$STUBS/services"
  unset ORCA_WORKTREE_ID ORCA_CLI_BIN_DIR FACTORY_ORCA_HOOK_LOG
  export HOME="$REPO/home" ORCA_WORKTREE_PATH="$WT"
  export PATH="$STUBS:/usr/bin:/bin"
}

# A bin/compose that logs to compose.log, announces and sleeps for watch, and
# exits 5 at once with compose-fails or after 2s with compose-fails-late.
compose_stub() {
  cat > "$1" <<STUB
#!/bin/bash
S="$STUBS"
STUB
  cat >> "$1" <<'STUB'
if [ "$1 $2" = 'config --services' ]; then cat "$S/services" 2> /dev/null || echo postgres; exit 0; fi
if [ "$1" = config ]; then printf 'services:\n  app:\n    develop:\n'; exit 0; fi
echo "compose $* in $PWD" >> "$S/compose.log"
[ ! -f "$S/compose-fails" ] || { echo 'compose failed' >&2; exit 5; }
[ ! -f "$S/compose-fails-late" ] || { sleep 2; echo 'compose failed late' >&2; exit 5; }
[ "$1" != watch ] || [ -f "$S/compose-silent" ] || echo 'Watch enabled'
[ "$1" != watch ] || sleep 300
STUB
  chmod +x "$1"
}

# Run bin/orca-setup, then stop the watch it left and wait for the backgrounded
# stub bin/orca-autostart to finish: the runner removes $REPO as soon as the test
# returns, and a stub still writing into $STUBS would race that removal.
run_setup() {
  expect_pass bash "$@"
  stop_watch
  [ -x "$WT/bin/orca-autostart" ] || return 0
  touch "$STUBS/autostart-go"
  for _ in $(seq 100); do [ ! -f "$STUBS/autostart.done" ] || return 0; sleep 0.1; done
  fail 'helper did not finish'
}

watch_pid() { cat "$FACTORY_SESSION_REGISTRY/watch-$1.pid" 2> /dev/null; }
watches() { pgrep -f "$WT/bin/compose watch" | wc -l | tr -d ' '; }
stop_watch() { "$ROOT/bin/session" watch-stop "${1:-2}" > /dev/null 2>&1 || true; }

# [dev-sessions-2468d4]
test_orca_config_wires_the_hooks() {
  grep -qxF '  setup: bash "${ORCA_WORKTREE_PATH:-.}/bin/orca-setup"' "$ROOT/orca.yaml" || fail 'setup hook not wired'
  grep -qxF '  archive: bash "${ORCA_WORKTREE_PATH:-.}/bin/orca-archive"' "$ROOT/orca.yaml" || fail 'archive hook not wired'
  ! grep -q 'ORCA_ROOT_PATH' "$ROOT/orca.yaml" || fail 'hooks depend on the main checkout'
  grep -qx 'setupAgentStartupPolicy: start-immediately' "$ROOT/orca.yaml" || fail 'agent does not start at once'
}

# [dev-sessions-0388a7]
# Orca reads an issue command from the top-level `issueCommand` of orca.yaml
# or from .orca/issue-command; neither may exist.
test_issue_workspace_opens_no_issue_command_pane() {
  ! grep -q '^issueCommand:' "$ROOT/orca.yaml" || fail 'orca.yaml configures an issue command'
  [ -z "$(git -C "$ROOT" ls-files .orca)" ] || fail 'the repository tracks .orca/'
}

# [dev-sessions-49530f]
# [dev-sessions-e35f4d]
test_setup_starts_the_stack_and_opens_the_ui() {
  orca_fixture
  export ORCA_WORKTREE_ID='repo-1::/x'
  cd /
  run_setup "$REPO/orca-setup"
  printf 'setup %s\nup %s\norca tab create --url http://127.0.0.1:11100 --worktree id:repo-1::/x --json\n' "$WT" "$WT" > "$REPO/expected"
  diff "$REPO/expected" "$LOG" || fail 'wrong calls'
  expect_output 'http://127.0.0.1:11100'
}

# [dev-sessions-35f075]
# Manual use from the workspace, no Orca variables.
test_setup_defaults_to_the_current_directory() {
  orca_fixture
  unset ORCA_WORKTREE_PATH
  cd "$WT" || fail "no $WT"
  run_setup "$REPO/orca-setup"
  grep -qxF "orca tab create --url http://127.0.0.1:11100 --worktree path:$WT --json" "$LOG" || fail "$(cat "$LOG")"
}

# [dev-sessions-06ec9c]
# Orca's own CLI directory when orca is not on PATH.
test_setup_uses_orca_cli_bin_dir() {
  orca_fixture
  mkdir "$REPO/orca-bin"
  mv "$STUBS/orca" "$REPO/orca-bin/orca"
  export ORCA_CLI_BIN_DIR="$REPO/orca-bin"
  run_setup "$REPO/orca-setup"
  grep -q '^orca tab create' "$LOG" || fail 'tab not opened through ORCA_CLI_BIN_DIR'
}

# [dev-sessions-8baa19]
test_failed_tab_does_not_fail_setup() {
  orca_fixture
  touch "$STUBS/orca-fails"
  run_setup "$REPO/orca-setup"
  expect_output 'NOTE: could not open http://127.0.0.1:11100 in an Orca browser tab'
  orca_fixture
  rm "$STUBS/orca"
  run_setup "$REPO/orca-setup"
  expect_output 'NOTE: could not open http://127.0.0.1:11100 in an Orca browser tab'
}


# [dev-sessions-e1aa32]
test_a_stack_without_a_ui_opens_no_tab() {
  orca_fixture
  echo postgres > "$STUBS/services"
  run_setup "$REPO/orca-setup"
  ! grep -q '^orca tab' "$LOG" || fail "a tab was opened: $(cat "$LOG")"
}

# [dev-sessions-8facfe]
test_the_helper_outlives_setup() {
  orca_fixture
  touch "$STUBS/autostart-hold"
  expect_pass bash -c 'echo piped | bash "$1"' _ "$REPO/orca-setup"
  [ ! -f "$STUBS/autostart.done" ] || fail 'setup waited for the helper'
  stop_watch
  [[ "$OUT" != *AUTOSTART-STDOUT* ]] || fail 'helper wrote to the hook output'
  touch "$STUBS/autostart-go"
  for _ in $(seq 50); do [ ! -f "$STUBS/autostart.done" ] || break; sleep 0.1; done
  [ -f "$STUBS/autostart.done" ] || fail 'helper did not finish'
  printf 'dir %s\nsurvived hangup\n' "$WT" > "$REPO/expected"
  diff "$REPO/expected" "$STUBS/autostart.seen" || fail 'helper not detached from the hook'
  grep -qx AUTOSTART-STDOUT "$HOME/.factory/orca-autostart.log" || fail 'helper output not logged'
}

# A helper that cannot start does not fail setup.
test_setup_without_the_helper_succeeds() {
  orca_fixture
  rm "$WT/bin/orca-autostart"
  run_setup "$REPO/orca-setup"
}

# [dev-sessions-c7336e]
test_failed_stack_fails_setup() {
  local step
  for step in setup up; do
    orca_fixture
    touch "$STUBS/$step-fails"
    expect_fail bash "$REPO/orca-setup"
    expect_output "$step failed"
    ! grep -q '^orca ' "$LOG" || fail "tab opened after $step failed"
    sleep 1 # a detached helper would have written its file by now
    [ ! -e "$STUBS/autostart.seen" ] || fail "autostart started after $step failed"
  done
}

# [dev-sessions-b8d551]
# The archive hook passes bin/down's failure through.
test_failed_down_fails_archive() {
  orca_fixture
  touch "$STUBS/down-fails"
  expect_fail bash "$REPO/orca-archive"
  expect_output 'down failed'
  grep -qxF "down $WT" "$LOG" || fail 'bin/down not run in the workspace'
}

# [dev-sessions-b8d551]
# A workspace without bin/down cannot be torn down; say so instead of succeeding.
test_archive_without_bin_down_fails() {
  orca_fixture
  rm "$WT/bin/down"
  expect_fail bash "$REPO/orca-archive"
  expect_output "$WT/bin/down"
}

# Real session scripts behind the archive hook, with a stub docker.
real_down_fixture() {
  orca_fixture
  local file
  for file in session compose down; do cp "$ROOT/bin/$file" "$WT/bin/$file"; done
  printf '#!/bin/bash\necho "docker $*" >> "%s/docker.log"\n[ "$1" != info ] || [ ! -f "%s/docker-down" ]\n' "$STUBS" "$STUBS" > "$STUBS/docker"
  printf '#!/bin/sh\nexit 0\n' > "$STUBS/lsof"
  chmod +x "$STUBS/docker" "$STUBS/lsof"
  export FACTORY_SESSION_REGISTRY="$REPO/registry"
  unset FACTORY_SESSION_SLOTS
  printf 'POSTGRES_USER=app\n' > "$WT/.env"
  SLOT="$("$WT/bin/session" claim "$WT")"
  printf 'FACTORY_SESSION_ID=%s\nCOMPOSE_PROJECT_NAME=factory-%s\n' "$SLOT" "$SLOT" > "$WT/.env.session"
}

# [dev-sessions-814c8b]
test_archive_removes_the_stack_and_frees_the_slot() {
  real_down_fixture
  cd /
  expect_pass bash "$REPO/orca-archive"
  grep -q 'compose .* down -v --remove-orphans' "$STUBS/docker.log" || fail 'stack not removed'
  [ -z "$("$WT/bin/session" list)" ] || fail 'slot still held'
  [ ! -e "$WT/.env.session" ] || fail 'session file left behind'
}

# [dev-sessions-814c8b]
test_archive_ends_the_watch() {
  local pid
  real_down_fixture
  compose_stub "$WT/bin/compose"
  "$WT/bin/session" watch-start "$SLOT" "$WT" > /dev/null
  pid="$(watch_pid "$SLOT")"
  cp "$ROOT/bin/compose" "$WT/bin/compose"
  expect_pass bash "$REPO/orca-archive"
  ! kill -0 "$pid" 2> /dev/null || { kill -- -"$pid"; fail 'watch still running'; }
  [ ! -e "$FACTORY_SESSION_REGISTRY/watch-$SLOT.pid" ] || fail 'watch record left'
  grep -q 'compose .* down -v --remove-orphans' "$STUBS/docker.log" || fail 'stack not removed'
}

# bin/down signals only a process that is still the watch.
test_down_leaves_a_recycled_pid() {
  local other
  real_down_fixture
  # Not a job of this shell, so killing it prints no notice.
  other="$(sh -c 'sleep 300 > /dev/null 2>&1 & echo $!')"
  mkdir -p "$FACTORY_SESSION_REGISTRY"
  echo "$other" > "$FACTORY_SESSION_REGISTRY/watch-$SLOT.pid"
  expect_pass "$WT/bin/down"
  kill -0 "$other" 2> /dev/null || fail 'another process was signalled'
  kill "$other"
  [ ! -e "$FACTORY_SESSION_REGISTRY/watch-$SLOT.pid" ] || fail 'watch record left'
}

# [dev-sessions-58db50]
test_archive_without_session_succeeds() {
  real_down_fixture
  "$WT/bin/session" release "$SLOT" "$WT"
  rm -f "$WT/.env.session" "$STUBS/docker.log"
  expect_pass bash "$REPO/orca-archive"
  expect_output 'nothing to tear down'
  [ ! -e "$STUBS/docker.log" ] || fail 'docker called without a session'
}

# [dev-sessions-b8d551]
# Docker down keeps the slot.
test_docker_down_keeps_the_slot() {
  real_down_fixture
  touch "$STUBS/docker-down"
  expect_fail bash "$REPO/orca-archive"
  expect_output 'Docker is not running'
  [ "$("$WT/bin/session" slot-for "$WT")" = "$SLOT" ] || fail 'slot released'
}

# Hook help needs nothing.
test_orca_hooks_describe_themselves() {
  local hook
  orca_fixture
  for hook in orca-setup orca-archive orca-autostart; do
    expect_pass bash "$REPO/$hook" --help
    expect_output "Usage: bin/$hook"
  done
  [ ! -e "$LOG" ] || fail 'help ran a session script'
}

# [dev-sessions-2d7182]
test_every_agent_reads_the_issue_url_rule() {
  local entry
  for entry in CLAUDE.md GEMINI.md; do
    grep -qxF '@AGENTS.md' "$ROOT/$entry" || fail "$entry does not load AGENTS.md"
  done
  grep -qF 'https://github.com/<owner>/<repo>/issues/<N>' "$ROOT/AGENTS.md" || fail 'AGENTS.md has no issue-URL rule'
  grep -qF 'means `/work <N>`' "$ROOT/AGENTS.md" || fail 'the rule does not map the URL to /work'
  grep -qF '`.claude/skills/work/SKILL.md`' "$ROOT/AGENTS.md" || fail 'the rule names no skill file for agents without /work'
  [ -f "$ROOT/.claude/skills/work/SKILL.md" ] || fail 'the /work skill file is missing'
}

# Whether an agent acts on that rule is model behaviour, proven in a real Orca
# issue workspace.

# Orca's terminal list JSON, one key per line, for "<handle>:<agent>" rows; an
# empty agent leaves agentIdentity out, as Orca does for a shell.
orca_terminals() {
  local row
  printf '{\n  "ok": true,\n  "result": {\n    "terminals": [\n'
  for row in "$@"; do
    printf '      {\n        "handle": "%s",\n        "title": "x",\n        "executionHostId": "local"' "${row%%:*}"
    [ -z "${row#*:}" ] || printf ',\n        "agentIdentity": "%s"' "${row#*:}"
    printf '\n      },\n'
  done
  printf '    ]\n  }\n}\n'
} > "$STUBS/list.json"

# Orca's terminal read --screen JSON for handle $1 with the JSON-encoded draft
# $2 (none when empty), written to read-<handle>.${3:-json}.
orca_screen() {
  {
    printf '{\n  "ok": true,\n  "result": {\n    "terminal": {\n      "handle": "%s",\n' "$1"
    printf '      "tail": [\n        "\\u276f"\n      ],\n      "source": "screen"'
    [ -z "$2" ] || printf ',\n      "draft": %s' "$2"
    printf '\n    }\n  }\n}\n'
  } > "$STUBS/read-$1.${3:-json}"
}

# Run the helper fast: one poll is allowed, then the bound has passed.
autostart() {
  FACTORY_AUTOSTART_TIMEOUT="${1:-0}" FACTORY_AUTOSTART_INTERVAL=0.1 bash "$REPO/orca-autostart"
}

ISSUE_URL='"https://github.com/my.org/my-app/issues/45"'

# [dev-sessions-a8fef1]
test_bare_issue_url_draft_is_submitted() {
  orca_fixture
  export ORCA_WORKTREE_ID='repo-1::/x'
  orca_terminals 'term_shell:' 'term_claude:claude'
  orca_screen term_claude "$ISSUE_URL"
  expect_pass autostart
  expect_output 'submitted'
  printf '%s\n' 'orca terminal list --worktree id:repo-1::/x --json' \
    'orca terminal read --terminal term_claude --screen --json' \
    'orca terminal send --terminal term_claude --enter --json' > "$REPO/expected"
  diff "$REPO/expected" "$LOG" || fail 'wrong calls'
}

# [dev-sessions-3ffdfc]
# Claude Code shows the draft a moment after start.
test_draft_that_appears_later_is_submitted() {
  orca_fixture
  orca_terminals 'term_claude:claude'
  orca_screen term_claude '' first
  orca_screen term_claude "$ISSUE_URL"
  expect_pass autostart 5
  [ "$(grep -c '^orca terminal read' "$LOG")" = 2 ] || fail "$(cat "$LOG")"
  [ "$(grep -c '^orca terminal send' "$LOG")" = 1 ] || fail 'Enter not sent once'
  grep -qxF "orca terminal list --worktree path:$WT --json" "$LOG" || fail 'workspace not selected by path'
}

# [dev-sessions-e3bd9c]
test_other_drafts_are_left_untouched() {
  local draft
  for draft in '"https://github.com/my.org/my-app/issues/45 please hurry"' \
    '"https://github.com/my.org/my-app/issues/45\nand more"' \
    '"https://github.com/someone/else/issues/45"' \
    '"https://github.com/myXorg/my-app/issues/45"' \
    '"https://github.com/my.org/my-app/pull/45"' \
    '"/work 45"'; do
    orca_fixture
    orca_terminals 'term_claude:claude'
    orca_screen term_claude "$draft"
    expect_pass autostart 5
    ! grep -q '^orca terminal send' "$LOG" || fail "submitted $draft"
    [ "$(grep -c '^orca terminal read' "$LOG")" = 1 ] || fail "kept polling after $draft"
  done
}

# [dev-sessions-2afb11]
# Two candidates are ambiguous; a shell is no candidate.
test_two_matching_terminals_are_left_untouched() {
  orca_fixture
  orca_terminals 'term_a:claude' 'term_b:claude'
  orca_screen term_a "$ISSUE_URL"
  orca_screen term_b "$ISSUE_URL"
  expect_pass autostart
  ! grep -q '^orca terminal send' "$LOG" || fail 'submitted an ambiguous draft'
  orca_fixture
  orca_terminals 'term_shell:'
  orca_screen term_shell "$ISSUE_URL"
  expect_pass autostart
  ! grep -q '^orca terminal \(read\|send\)' "$LOG" || fail 'touched a shell terminal'
}

# [dev-sessions-5b0ac4]
# [dev-sessions-b5e9a6]
test_no_prompt_within_the_bound() {
  orca_fixture
  orca_terminals
  expect_pass autostart 2
  [ "$(grep -c '^orca terminal list' "$LOG")" -gt 1 ] || fail 'did not poll until the bound'
  expect_output 'no issue URL draft'
  orca_fixture
  orca_terminals 'term_claude:claude'
  orca_screen term_claude '""'
  expect_pass autostart
  ! grep -q '^orca terminal send' "$LOG" || fail 'submitted an empty draft'
  orca_fixture
  touch "$STUBS/orca-fails"
  expect_pass autostart
  ! grep -q '^orca terminal send' "$LOG" || fail 'sent input through a failing CLI'
  orca_fixture
  rm "$STUBS/orca"
  expect_pass autostart 5
  expect_output 'no orca CLI'
  # No origin: the repository is unknown, so nothing can match.
  orca_fixture
  git -C "$WT" remote remove origin
  orca_terminals 'term_claude:claude'
  orca_screen term_claude "$ISSUE_URL"
  expect_pass autostart
  ! grep -q '^orca terminal send' "$LOG" || fail 'sent input without knowing the repository'
}

# The helper is a workaround with a named way out.
test_orca_autostart_is_marked_for_removal() {
  grep -q 'TODO' "$ROOT/bin/orca-autostart" || fail 'helper not marked for removal'
  grep -q 'orca-autostart' "$ROOT/orca.yaml" || fail 'orca.yaml does not mention the helper'
}


# The hook log, at its default place under the fixture's HOME.
hook_log() { cat "$REPO/home/.factory/orca-hooks.log" 2> /dev/null; }
TS='[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z'

# [dev-sessions-518d81]
# Run from another directory, as Orca does.
test_archive_run_is_logged() {
  real_down_fixture
  cd /
  expect_pass bash "$REPO/orca-archive"
  [ "$(hook_log | wc -l | tr -d ' ')" = 2 ] || fail "expected two lines: $(hook_log)"
  hook_log | sed -n 1p | grep -qxE "$TS archive $WT slot=$SLOT started" || fail "start line: $(hook_log)"
  hook_log | sed -n 2p | grep -qxE "$TS archive $WT slot=$SLOT exited 0" || fail "exit line: $(hook_log)"
}

# [dev-sessions-77bfa7]
test_failed_hook_is_logged() {
  orca_fixture
  touch "$STUBS/down-fails"
  expect_fail bash "$REPO/orca-archive"
  hook_log | sed -n 1p | grep -qxE "$TS archive $WT slot=- started" || fail "start line: $(hook_log)"
  hook_log | tail -n 1 | grep -qxE "$TS archive $WT slot=- exited 3" || fail "exit line: $(hook_log)"
}

# [dev-sessions-7c67ee]
# Success, and a failed bin/up still fails the hook.
test_setup_run_is_logged() {
  orca_fixture
  run_setup "$REPO/orca-setup"
  hook_log | sed -n 1p | grep -qxE "$TS setup $WT slot=- started" || fail "start line: $(hook_log)"
  hook_log | sed -n 2p | grep -qxE "$TS setup $WT slot=2 exited 0" || fail "exit line: $(hook_log)"
  orca_fixture
  rm -f "$REPO/home/.factory/orca-hooks.log"
  touch "$STUBS/up-fails"
  expect_fail bash "$REPO/orca-setup"
  hook_log | tail -n 1 | grep -qxE "$TS setup $WT slot=- exited 3" || fail "failed setup not logged: $(hook_log)"
}

# [dev-sessions-77bfa7]
# FACTORY_ORCA_HOOK_LOG moves the log; one that cannot be written never
# changes a hook's result.
test_hook_log_path_is_configurable_and_never_fails_a_hook() {
  orca_fixture
  export FACTORY_ORCA_HOOK_LOG="$REPO/elsewhere/hooks.log"
  expect_pass bash "$REPO/orca-archive"
  run_setup "$REPO/orca-setup"
  grep -qE ' archive .* exited 0$' "$FACTORY_ORCA_HOOK_LOG" || fail "archive not logged at the override: $(cat "$FACTORY_ORCA_HOOK_LOG")"
  grep -qE ' setup .* exited 0$' "$FACTORY_ORCA_HOOK_LOG" || fail 'setup not logged at the override'
  [ -z "$(hook_log)" ] || fail 'the default log was written despite the override'
  orca_fixture
  touch "$REPO/file"
  export FACTORY_ORCA_HOOK_LOG="$REPO/file/orca-hooks.log"
  expect_pass bash "$REPO/orca-archive"
  run_setup "$REPO/orca-setup"
}

# [dev-sessions-8f5568]
# The watch outlives a hook run from a pipe.
test_setup_leaves_a_watch() {
  local pid
  orca_fixture
  expect_pass bash -c 'echo piped | bash "$1"' _ "$REPO/orca-setup"
  expect_output "$HOME/.factory/orca-watch-2.log"
  pid="$(watch_pid 2)"
  [[ "$(ps -o args= -p "${pid:-0}")" == *"$WT/bin/compose watch" ]] || { stop_watch; fail "no watch recorded: ${pid:-none}"; }
  grep -qx "compose watch in $(cd "$WT" && pwd -P)" "$STUBS/compose.log" || { stop_watch; fail 'watch not run in the workspace'; }
  [ -f "$HOME/.factory/orca-watch-2.log" ] || { stop_watch; fail 'no watch log'; }
  run_setup "$REPO/orca-setup"
}

# [dev-sessions-d773fd]
test_setup_again_keeps_one_watch() {
  local count
  orca_fixture
  touch "$STUBS/autostart-go"
  expect_pass bash "$REPO/orca-setup"
  expect_pass bash "$REPO/orca-setup"
  count="$(watches)"
  stop_watch
  [ "$count" = 1 ] || fail "$count watches running"
  [ "$(watches)" = 0 ] || fail 'watch-stop left a watch'
  run_setup "$REPO/orca-setup"
}

# [dev-sessions-c7336e]
test_failed_stack_starts_no_watch() {
  local step
  for step in setup up; do
    orca_fixture
    touch "$STUBS/$step-fails"
    expect_fail bash "$REPO/orca-setup"
    [ ! -e "$STUBS/compose.log" ] || fail "watch started after $step failed"
    [ -z "$(watch_pid 2)" ] || fail "watch recorded after $step failed"
  done
}

# [dev-sessions-27c10c]
# Failing at once, or after a while.
test_watch_failure_does_not_fail_setup() {
  local marker
  for marker in compose-fails compose-fails-late; do
    orca_fixture
    touch "$STUBS/$marker"
    run_setup "$REPO/orca-setup"
    expect_output 'NOTE: the stack is not watching'
    grep -q '^orca tab create' "$LOG" || fail "tabs not opened after the watch failed ($marker)"
  done
}

# [dev-sessions-2a2c77]
test_ci_shellchecks_the_orca_hooks() {
  local step script
  step="$(grep -E 'koalaman/shellcheck' "$ROOT/.github/workflows/checks.yml")"
  for script in bin/orca-setup bin/orca-archive bin/orca-autostart; do
    [[ " $step " == *" $script "* ]] || fail "shellcheck step misses $script"
  done
}
