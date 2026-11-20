# shellcheck shell=bash disable=SC2154
# bin/doctor: one line per check, a fix under each problem, exit 1 only on a
# missing prerequisite. A restricted PATH of stubs stands in for the real tools;
# the stubs read their answers from the environment.

doctor_fixture() {
  local tool
  cp -R "$ROOT/bin" .
  touch .env
  git config core.hooksPath .githooks
  TOOLS="$REPO/tools"
  mkdir -p "$TOOLS"
  for tool in bash sh env cat grep sed awk tr cut uname dirname git head rm; do
    ln -s "$(command -v "$tool")" "$TOOLS/$tool"
  done
  cat > "$TOOLS/docker" <<'STUB'
#!/bin/sh
case "$1 $2" in
  "info "*) exit "${DOCKER_INFO:-0}" ;;
  "compose version") echo "${COMPOSE_VERSION:-2.29.1}" ;;
esac
STUB
  cat > "$TOOLS/gh" <<'STUB'
#!/bin/sh
[ "$1 $2" = "auth status" ] && exit "${GH_AUTH:-0}"
exit 0
STUB
  for tool in ss claude orca; do printf '#!/bin/sh\nexit 0\n' > "$TOOLS/$tool"; done
  cat > "$TOOLS/node" <<'STUB'
#!/bin/sh
[ "$1" = --version ] && echo "${NODE_VERSION-v24.11.0}"
exit 0
STUB
  chmod +x "$TOOLS/node"
  # Only the stubs: chmod follows a link, and Linux refuses it on /usr/bin.
  chmod +x "$TOOLS/docker" "$TOOLS/gh" "$TOOLS/ss" "$TOOLS/claude" "$TOOLS/orca"
  echo '6.5.0-generic' > "$REPO/osrelease"
  # A ready machine runs Claude Code in the auto permission mode automatic mode needs.
  mkdir -p "$REPO/claude-config"
  printf '{\n  "permissions": {\n    "defaultMode": "auto"\n  }\n}\n' > "$REPO/claude-config/settings.json"
  export PATH="$TOOLS" FACTORY_DOCTOR_OSRELEASE="$REPO/osrelease" FACTORY_DOCTOR_ROOT="$REPO" CLAUDE_CONFIG_DIR="$REPO/claude-config"
  unset WSL_DISTRO_NAME DOCKER_INFO COMPOSE_VERSION GH_AUTH NODE_VERSION
}

# The line for a check, and the fix line under it.
line() { printf '%s\n' "$OUT" | grep -E "^(ok  |warn|FAIL) $1" | head -n 1; }
fix_of() { printf '%s\n' "$OUT" | grep -A1 -E "^(warn|FAIL) $1" | sed -n 's/^ *fix: //p' | head -n 1; }

# [dev-sessions-a9db7c]
test_ready_machine_passes() {
  doctor_fixture
  expect_pass bin/doctor
  local bad
  bad="$(printf '%s\n' "$OUT" | grep -E '^(warn|FAIL)' || true)"
  [ -z "$bad" ] || fail "not every check is ok: $OUT"
  [ "$(printf '%s\n' "$OUT" | grep -c '^ok  ')" -ge 8 ] || fail "too few checks: $OUT"
}

# [dev-sessions-60b984]
test_missing_docker_names_the_install() {
  doctor_fixture
  rm "$TOOLS/docker"
  expect_fail bin/doctor
  [[ "$(line docker)" == FAIL* ]] || fail "docker line: $(line docker)"
  [[ "$(fix_of docker)" == *Docker* ]] || fail "docker fix: $(fix_of docker)"
}

# [dev-sessions-a1857d]
test_stopped_daemon_fails() {
  doctor_fixture
  DOCKER_INFO=1 expect_fail bin/doctor
  [[ "$(line 'Docker daemon')" == FAIL* ]] || fail "daemon line: $OUT"
  [[ "$(fix_of 'Docker daemon')" == *[Ss]tart* ]] || fail "daemon fix: $(fix_of 'Docker daemon')"
}

# [dev-sessions-a1857d]
test_old_compose_fails_and_the_floor_passes() {
  doctor_fixture
  COMPOSE_VERSION=2.21.9 expect_fail bin/doctor
  [[ "$(line 'Docker Compose')" == FAIL* ]] || fail "compose 2.21.9: $OUT"
  COMPOSE_VERSION=v2.22.0 expect_pass bin/doctor
  [[ "$(line 'Docker Compose')" == ok* ]] || fail "compose 2.22.0: $OUT"
  COMPOSE_VERSION=5.0.1 expect_pass bin/doctor
}

# [dev-sessions-a1857d]
test_no_port_tool_fails() {
  doctor_fixture
  rm "$TOOLS/ss"
  expect_fail bin/doctor
  [[ "$(line 'ss or lsof')" == FAIL* ]] || fail "port tool line: $OUT"
}

# [dev-sessions-88c848]
test_unauthenticated_gh_fails_with_the_login() {
  doctor_fixture
  GH_AUTH=1 expect_fail bin/doctor
  [[ "$(line gh)" == FAIL* ]] || fail "gh line: $OUT"
  [[ "$(fix_of gh)" == *'gh auth login'* ]] || fail "gh fix: $(fix_of gh)"
}

# [dev-sessions-651c80]
test_optional_tools_only_warn() {
  doctor_fixture
  rm "$TOOLS/claude" "$TOOLS/orca" .env
  git config --unset core.hooksPath
  expect_pass bin/doctor
  [[ "$(line 'Claude Code')" == warn* ]] || fail "claude: $OUT"
  [[ "$(line Orca)" == warn* ]] || fail "orca: $OUT"
  [[ "$(line .env)" == warn* ]] || fail ".env: $OUT"
  [[ "$(fix_of .env)" == *bin/setup* ]] || fail ".env fix: $(fix_of .env)"
  [[ "$(line 'git hooks')" == warn* ]] || fail "hooks: $OUT"
  [[ "$(fix_of 'git hooks')" == *bin/setup* ]] || fail "hooks fix: $(fix_of 'git hooks')"
}

# [dev-sessions-13f369]
test_wsl_checkout_on_the_windows_drive_fails() {
  doctor_fixture
  WSL_DISTRO_NAME=Ubuntu FACTORY_DOCTOR_ROOT=/mnt/c/src/app expect_fail bin/doctor
  [[ "$(line 'WSL checkout')" == FAIL* ]] || fail "wsl line: $OUT"
  [[ "$(fix_of 'WSL checkout')" == *'Linux home'* ]] || fail "wsl fix: $(fix_of 'WSL checkout')"
}

# [dev-sessions-472c77]
test_wsl_autocrlf_only_warns() {
  doctor_fixture
  echo '5.15.153.1-microsoft-standard-WSL2' > "$REPO/osrelease"
  git config core.autocrlf true
  expect_pass bin/doctor
  [[ "$(line 'WSL checkout')" == ok* ]] || fail "wsl checkout: $OUT"
  [[ "$(line 'WSL line endings')" == warn* ]] || fail "autocrlf: $OUT"
}

# [dev-sessions-2af609]
test_no_wsl_checks_elsewhere() {
  doctor_fixture
  expect_pass bin/doctor
  if printf '%s\n' "$OUT" | grep -q WSL; then fail "WSL line outside WSL: $OUT"; fi
}

# [dev-sessions-40df32]
test_doctor_help_needs_nothing() {
  doctor_fixture
  rm "$TOOLS/docker"
  expect_pass bin/doctor --help
  expect_output 'Usage'
}

# [dev-sessions-0ed22e]
test_node_line_notes_the_openspec_download() {
  local pinned
  doctor_fixture
  pinned="$(sed -n 's/^OPENSPEC_VERSION="\(.*\)"$/\1/p' bin/openspec)"
  [ -n "$pinned" ] || fail 'no OPENSPEC_VERSION in bin/openspec'
  expect_pass bin/doctor
  [[ "$(line Node)" == ok* ]] || fail "node line: $(line Node)"
  [[ "$(line Node)" == *"v24.11.0"* ]] || fail "node version not shown: $(line Node)"
  [[ "$(line Node)" == *"first bin/openspec run downloads OpenSpec $pinned"* ]] || fail "download not noted: $(line Node)"
}

# [dev-sessions-1bfb77]
test_missing_or_old_node_only_warns() {
  local version host_path="$PATH"
  for version in missing v22.3.0 v; do
    PATH="$host_path"
    rm -rf bin "$REPO/tools"
    doctor_fixture
    if [ "$version" = missing ]; then rm "$TOOLS/node"; else export NODE_VERSION="$version"; fi
    expect_pass bin/doctor
    [[ "$(line Node)" == warn* ]] || fail "node line with $version: $(line Node)"
    [[ "$(fix_of Node)" == *https://nodejs.org* ]] || fail "node fix with $version: $(fix_of Node)"
  done
}

# [agent-workflow-2276f2]
test_auto_mode_is_ok() {
  doctor_fixture
  expect_pass bin/doctor
  [[ "$(line 'Claude Code auto permission mode')" == ok* ]] || fail "auto mode: $OUT"
}

# [agent-workflow-d6f086]
test_missing_auto_mode_only_warns() {
  doctor_fixture
  local settings="$CLAUDE_CONFIG_DIR/settings.json" content
  for content in '' '{"permissions": {"defaultMode": "default"}}' 'not json'; do
    if [ -z "$content" ]; then rm -f "$settings"; else printf '%s\n' "$content" > "$settings"; fi
    expect_pass bin/doctor
    [[ "$(line 'Claude Code auto permission mode')" == warn* ]] || fail "auto mode with '$content': $OUT"
    [[ "$(line 'Claude Code auto permission mode')" == *"automatic mode"* ]] || fail "the warning does not name automatic mode: $OUT"
    [[ "$(fix_of 'Claude Code auto permission mode')" == *'"defaultMode": "auto"'* ]] || fail "fix: $(fix_of 'Claude Code auto permission mode')"
  done
}

test_auto_mode_is_not_checked_without_claude() {
  doctor_fixture
  rm "$TOOLS/claude"
  expect_pass bin/doctor
  [ -z "$(line 'Claude Code auto permission mode')" ] || fail "checked the mode without Claude Code: $OUT"
}
