# shellcheck shell=bash disable=SC2154,SC2034,SC2016,SC2088
# Session command tests against a copy of the scripts in a path with a space.
# (SC2088: expected help text holds a literal ~.)
# Stub docker logs every call to $STUBS/docker.log; behaviour files in $STUBS:
#   docker-down  `docker info` fails       up-fails     `compose up` fails
#   ps-ids       `docker ps -aq` output    ps-states    `docker ps --format` output
#   volume-ids, network-ids, image-ids     `docker <kind> ls -q` output
#   reap-containers  project<TAB>dir lines for bin/session reap's discovery
#   develop      `compose config` names a watched service
#   seed-fails   `compose exec` fails     no-backend   `compose ps` lists no backend
#   ps-running   N: the next N `docker ps -q --filter` polls list a container
#   stop-fails   `compose stop` fails with status 3
#   ps-fails     `docker ps -q --filter` fails with status 4
# Listings stay empty until a `compose up` has run (the `started` marker).
stack_fixture() {
  local tool file
  # A second call in one test starts again from the caller's PATH.
  HOST_PATH="${HOST_PATH:-$PATH}"
  PATH="$HOST_PATH"
  PROJ="$REPO/work tree"
  STUBS="$REPO/stubs"
  TOOLS="$REPO/tools"
  rm -rf "$PROJ" "$STUBS" "$TOOLS" "$REPO/registry"
  mkdir -p "$PROJ/bin" "$STUBS" "$TOOLS" "$REPO/home"
  for tool in bash sh cat mkdir rm sed awk grep cut sort seq sleep hostname tr chmod dirname ls wc git tail touch ps nohup od head; do
    ln -s "$(command -v "$tool")" "$TOOLS/$tool"
  done
  for file in session compose up stop down logs seed setup-env.sh; do
    cp "$ROOT/bin/$file" "$PROJ/bin/$file"
  done
  cp "$ROOT/docker-compose.yml" "$ROOT/docker-compose.local.yml" "$ROOT/docker-compose.session.yml" "$ROOT/.env.example" "$PROJ/"
  printf 'POSTGRES_USER=app\nPOSTGRES_DB=app\nPOSTGRES_PASSWORD=synthetic-password\n' > "$PROJ/.env"
  cat > "$STUBS/docker" <<'STUB'
#!/bin/bash
dir="$(cd "$(dirname "$0")" && pwd)"
echo "docker $*" >> "$dir/docker.log"
if [ "$1 $2 $3 $4" = 'ps -a --filter label=com.docker.compose.project' ]; then
  cat "$dir/reap-containers" 2> /dev/null
  exit 0
fi
case "$1" in
  info) [ -f "$dir/docker-down" ] && exit 1; exit 0 ;;
  compose)
    printf 'COMPOSE_PROJECT_NAME=%s\n' "${COMPOSE_PROJECT_NAME:-}" > "$dir/compose-env"
    case "$*" in
      *" config --services") printf 'postgres\nbackend\nui\n'; exit 0 ;;
      *" config") [ -f "$dir/develop" ] && printf 'services:\n  app:\n    develop:\n'; exit 0 ;;
      *" ps --status running -q backend") [ -f "$dir/started" ] && [ ! -f "$dir/no-backend" ] && echo b1; exit 0 ;;
      *" stop") [ -f "$dir/stop-fails" ] && exit 3; exit 0 ;;
      *" exec "*) [ -f "$dir/seed-fails" ] && { echo 'seed: refusing to seed a stack bin/up did not start' >&2; exit 1; }; echo 'Created: demo@example.com'; exit 0 ;;
    esac
    for arg in "$@"; do
      [ "$arg" = up ] || continue
      touch "$dir/started"
      [ -f "$dir/up-fails" ] && exit 1
    done
    exit 0 ;;
  # Nothing exists for a project until Compose has started it.
  ps | volume | network | image) [ -f "$dir/started" ] || exit 0 ;;
esac
case "$1" in
  ps)
    [ "$2" != -q ] || [ ! -f "$dir/ps-fails" ] || exit 4
    if [ "$2" = -q ] && [ -f "$dir/ps-running" ]; then
      left="$(cat "$dir/ps-running")"
      [ "$left" -eq 0 ] || { echo c1; echo $((left - 1)) > "$dir/ps-running"; }
      exit 0
    fi
    case "$*" in
      *--format*) cat "$dir/ps-states" 2> /dev/null ;;
      *) cat "$dir/ps-ids" 2> /dev/null ;;
    esac
    exit 0 ;;
  volume | network | image)
    [ "$2" = ls ] && cat "$dir/$1-ids" 2> /dev/null
    exit 0 ;;
esac
exit 0
STUB
  printf '#!/bin/sh\necho "COMMAND PID USER FD TYPE DEVICE SIZE/OFF NODE NAME"\n' > "$STUBS/lsof"
  chmod +x "$STUBS/docker" "$STUBS/lsof"
  unset COMPOSE_PROJECT_NAME FACTORY_PUBLIC_HOST FACTORY_BIND_HOST FACTORY_SESSION_SLOTS FACTORY_ALLOW_WILDCARD_BIND
  export HOME="$REPO/home" FACTORY_SESSION_REGISTRY="$REPO/registry"
  export PATH="$STUBS:$TOOLS"
  REAL="$(cd "$PROJ" && pwd -P)"
}

write_session() {
  printf 'FACTORY_SESSION_ID=2\nCOMPOSE_PROJECT_NAME=factory-2\nFACTORY_PORT_POSTGRES=11102\n' > "$PROJ/.env.session"
}

# [dev-sessions-02b749]
test_compose_layers_the_sessions_files() {
  stack_fixture
  write_session
  expect_pass "$PROJ/bin/compose" config
  grep -qxF "docker compose --project-directory $REAL --env-file $REAL/.env --env-file $REAL/.env.session -f $REAL/docker-compose.yml -f $REAL/docker-compose.local.yml -f $REAL/docker-compose.session.yml config" "$STUBS/docker.log" \
    || fail "files not layered: $(cat "$STUBS/docker.log")"
  grep -qx 'COMPOSE_PROJECT_NAME=factory-2' "$STUBS/compose-env" || fail 'project not taken from the session'
}

# [dev-sessions-7d683e]
test_compose_without_session_fails() {
  stack_fixture
  expect_fail "$PROJ/bin/compose" ps
  expect_output 'No session for this worktree — run bin/up'
  [ ! -e "$STUBS/docker.log" ] || fail 'Compose invoked without a session'
}

test_compose_without_env_fails() {
  stack_fixture
  write_session
  rm "$PROJ/.env"
  expect_fail "$PROJ/bin/compose" ps
  expect_output 'No .env — run bin/setup'
  [ ! -e "$STUBS/docker.log" ] || fail 'Compose invoked without .env'
}

# [dev-sessions-9bfe82] [dev-sessions-234ed4] [dev-sessions-5f2d9b]
# Slot 1 is taken, so this worktree gets slot 2; bin/up runs from elsewhere.
test_up_starts_the_session() {
  local line
  stack_fixture
  mkdir "$REPO/other"
  "$PROJ/bin/session" claim "$REPO/other" > /dev/null
  cd /
  expect_pass "$PROJ/bin/up"
  expect_output 'Session 2 (factory-2) is up'
  expect_output 'UI        http://127.0.0.1:11100'
  expect_output 'GraphQL   http://127.0.0.1:11101/graphql'
  expect_output 'Postgres  postgres://app@127.0.0.1:11102/app'
  [ "$(printf '%s\n' "$OUT" | grep -c '://')" = 3 ] || fail "another URL is printed: $OUT"
  [[ "$OUT" != *synthetic-password* ]] || fail 'the password is printed'
  grep -q 'compose .* up -d --build --wait --wait-timeout 300 --remove-orphans$' "$STUBS/docker.log" \
    || fail 'stack not started in the background with --wait'
  grep -qx 'COMPOSE_PROJECT_NAME=factory-2' "$STUBS/compose-env" || fail 'wrong project'
  # ls -l is the one mode listing shared by BSD and GNU (stat flags differ).
  # shellcheck disable=SC2012
  [ "$(ls -l "$PROJ/.env.session" | cut -c1-10)" = '-rw-------' ] || fail 'session file is not private'
  for line in FACTORY_SESSION_ID=2 COMPOSE_PROJECT_NAME=factory-2 FACTORY_PORT_UI=11100 FACTORY_PORT_API=11101 \
    FACTORY_PORT_POSTGRES=11102 FACTORY_PUBLIC_HOST=127.0.0.1 FACTORY_BIND_HOST=127.0.0.1; do
    grep -qx "$line" "$PROJ/.env.session" || fail "session file lacks $line"
  done
  expect_pass "$PROJ/bin/up"
  expect_output 'postgres://app@127.0.0.1:11102/app'
  [ "$("$PROJ/bin/session" slot-for "$PROJ")" = 2 ] || fail 'second run changed the slot'
}

# [dev-sessions-35b81e]
test_up_writes_a_missing_env_first() {
  stack_fixture
  rm "$PROJ/.env"
  expect_pass "$PROJ/bin/up"
  grep -Eq '^POSTGRES_PASSWORD=[0-9a-f]{32}$' "$PROJ/.env" || fail ".env not written: $(cat "$PROJ/.env" 2> /dev/null)"
  grep -q ' up -d ' "$STUBS/docker.log" || fail 'stack not started'
}

# [dev-sessions-fe78a8]
# Once the stack is healthy, bin/up --watch hands the terminal to Compose's
# watch, which stays attached. The Docker proof shows a change reaching the
# container.
test_up_watch_stays_attached() {
  local up watch
  stack_fixture
  touch "$STUBS/develop"
  expect_pass "$PROJ/bin/up" --watch
  up="$(grep -n ' up -d --build --wait ' "$STUBS/docker.log" | cut -d: -f1)"
  watch="$(grep -n '^docker compose .* watch$' "$STUBS/docker.log" | cut -d: -f1)"
  [ -n "$up" ] && [ -n "$watch" ] || fail "bin/up --watch did not start and then watch:"$'\n'"$(cat "$STUBS/docker.log")"
  [ "$watch" -gt "$up" ] || fail 'the watch started before the stack was up'
  [ "$(tail -1 "$STUBS/docker.log")" = "$(sed -n "${watch}p" "$STUBS/docker.log")" ] || fail 'bin/up ran something after the watch'
}

# [dev-sessions-1f72de]
test_up_watch_with_nothing_to_watch() {
  stack_fixture
  expect_pass "$PROJ/bin/up" --watch
  expect_output 'Nothing to watch yet'
  ! grep -q '^docker compose .* watch$' "$STUBS/docker.log" || fail 'a watch was started'
}

test_up_rejects_unknown_arguments() {
  stack_fixture
  expect_fail "$PROJ/bin/up" --wait
  expect_output 'bin/up --help'
  [ ! -e "$STUBS/docker.log" ] || fail 'docker called'
}

# [dev-sessions-01b88b]
test_public_and_bind_hosts() {
  stack_fixture
  export FACTORY_PUBLIC_HOST=192.0.2.7 FACTORY_BIND_HOST=192.0.2.8
  expect_pass "$PROJ/bin/up"
  expect_output 'postgres://app@192.0.2.7:10102/app'
  grep -qx 'FACTORY_PUBLIC_HOST=192.0.2.7' "$PROJ/.env.session" || fail 'public host not recorded'
  grep -qx 'FACTORY_BIND_HOST=192.0.2.8' "$PROJ/.env.session" || fail 'bind host not recorded'
  grep -qF 'host_ip: ${FACTORY_BIND_HOST}' "$PROJ/docker-compose.session.yml" \
    || fail 'ports are not bound to the bind host'
}

# [dev-sessions-76daa7]
test_hosts_from_env_file() {
  stack_fixture
  mkdir -p "$HOME/.factory"
  printf 'FACTORY_PUBLIC_HOST=dev.example.test\nFACTORY_BIND_HOST=192.0.2.7\n' > "$HOME/.factory/env"
  expect_pass "$PROJ/bin/up"
  expect_output 'postgres://app@dev.example.test:10102/app'
  grep -qx 'FACTORY_PUBLIC_HOST=dev.example.test' "$PROJ/.env.session" || fail 'public host not recorded'
  grep -qx 'FACTORY_BIND_HOST=192.0.2.7' "$PROJ/.env.session" || fail 'bind host not recorded'
}

# bin/up --help lists the host variables and documents no remote dev server.
test_help_names_no_remote_server() {
  stack_fixture
  expect_pass "$PROJ/bin/up" --help
  expect_output 'FACTORY_PUBLIC_HOST'
  expect_output 'FACTORY_BIND_HOST'
  expect_output 'FACTORY_ALLOW_WILDCARD_BIND'
  ! grep -qiE 'remote dev server|private network' <<< "$OUT" || fail "bin/up --help documents a remote dev server: $OUT"
}

test_exported_hosts_win() {
  stack_fixture
  mkdir -p "$HOME/.factory"
  printf 'FACTORY_PUBLIC_HOST=file.example\nFACTORY_BIND_HOST=192.0.2.8\n' > "$HOME/.factory/env"
  export FACTORY_PUBLIC_HOST=exported.example FACTORY_BIND_HOST=192.0.2.9
  expect_pass "$PROJ/bin/up"
  expect_output 'postgres://app@exported.example:10102/app'
  grep -qx 'FACTORY_BIND_HOST=192.0.2.9' "$PROJ/.env.session" || fail 'exported bind host lost'
}

# [dev-sessions-a7afd3]
test_help_names_the_wildcard_override() {
  stack_fixture
  expect_pass "$PROJ/bin/up" --help
  expect_output 'FACTORY_ALLOW_WILDCARD_BIND'
  expect_output 'refused'
}

# A refused bin/up asked Docker nothing but whether it runs, and claimed nothing.
expect_nothing_started() {
  [ ! -e "$PROJ/.env.session" ] || fail 'session file written'
  [ -z "$(ls -A "$REPO/registry" 2> /dev/null)" ] || fail "slot claimed: $(ls -A "$REPO/registry")"
  ! grep -qv '^docker info' "$STUBS/docker.log" 2> /dev/null || fail "docker called: $(cat "$STUBS/docker.log")"
}

# [dev-sessions-08d768]
test_up_refuses_an_ipv4_wildcard() {
  stack_fixture
  export FACTORY_BIND_HOST=0.0.0.0
  expect_fail "$PROJ/bin/up"
  expect_output 'every network interface'
  expect_output 'FACTORY_ALLOW_WILDCARD_BIND=1'
  expect_nothing_started
}

# [dev-sessions-699a23]
test_up_refuses_an_ipv6_wildcard() {
  stack_fixture
  mkdir -p "$HOME/.factory"
  printf 'FACTORY_BIND_HOST=::\n' > "$HOME/.factory/env"
  expect_fail "$PROJ/bin/up"
  expect_output 'FACTORY_BIND_HOST=:: publishes'
  expect_nothing_started
  stack_fixture
  export FACTORY_BIND_HOST='[::]'
  expect_fail "$PROJ/bin/up"
  expect_output 'every network interface'
  expect_nothing_started
}

# [dev-sessions-97b234] A quoted value or a trailing comment in the machine env file, or
# another spelling of a wildcard, is still a wildcard.
test_up_refuses_any_spelling_of_a_wildcard() {
  local value
  for value in '"0.0.0.0"' "'0.0.0.0'" '0.0.0.0 # lan' '::0' '[::0]' '0:0:0:0:0:0:0:0' '::ffff:0.0.0.0' '0'; do
    stack_fixture
    mkdir -p "$HOME/.factory"
    printf 'FACTORY_BIND_HOST=%s\n' "$value" > "$HOME/.factory/env"
    expect_fail "$PROJ/bin/up"
    expect_output 'every network interface'
    expect_nothing_started
  done
}

# [dev-sessions-97b234]
test_up_refuses_a_quoted_exported_wildcard() {
  stack_fixture
  export FACTORY_BIND_HOST='"0.0.0.0"'
  expect_fail "$PROJ/bin/up"
  expect_output 'every network interface'
  expect_nothing_started
}

test_up_unquotes_the_machine_env_file() {
  stack_fixture
  mkdir -p "$HOME/.factory"
  printf 'FACTORY_BIND_HOST="192.0.2.7" # lan\nFACTORY_PUBLIC_HOST='"'"'dev.example.test'"'"'\n' > "$HOME/.factory/env"
  expect_pass "$PROJ/bin/up"
  grep -qx 'FACTORY_BIND_HOST=192.0.2.7' "$PROJ/.env.session" || fail "bind host not unquoted: $(cat "$PROJ/.env.session")"
  grep -qx 'FACTORY_PUBLIC_HOST=dev.example.test' "$PROJ/.env.session" || fail "public host not unquoted: $(cat "$PROJ/.env.session")"
}

# [dev-sessions-7e2a45]
test_up_takes_only_1_as_the_override() {
  stack_fixture
  export FACTORY_BIND_HOST=0.0.0.0 FACTORY_ALLOW_WILDCARD_BIND=yes
  expect_fail "$PROJ/bin/up"
  expect_output 'every network interface'
  expect_nothing_started
}

# [dev-sessions-0cd666]
test_up_override_starts_with_a_warning() {
  stack_fixture
  export FACTORY_BIND_HOST=0.0.0.0 FACTORY_ALLOW_WILDCARD_BIND=1
  expect_pass "$PROJ/bin/up"
  expect_output 'WARNING: FACTORY_BIND_HOST=0.0.0.0'
  grep -qx 'FACTORY_BIND_HOST=0.0.0.0' "$PROJ/.env.session" || fail 'wildcard not recorded'
}

# [dev-sessions-68d352]
test_up_override_from_the_env_file() {
  stack_fixture
  mkdir -p "$HOME/.factory"
  printf 'FACTORY_BIND_HOST=0.0.0.0\nFACTORY_ALLOW_WILDCARD_BIND=1\n' > "$HOME/.factory/env"
  expect_pass "$PROJ/bin/up"
  expect_output 'WARNING:'
  grep -qx 'FACTORY_BIND_HOST=0.0.0.0' "$PROJ/.env.session" || fail 'wildcard not recorded'
}

test_up_accepts_ipv6_loopback() {
  stack_fixture
  export FACTORY_BIND_HOST=::1
  expect_pass "$PROJ/bin/up"
  [[ "$OUT" != *WARNING* ]] || fail "warned on loopback: $OUT"
}

# [dev-sessions-ca988c]
test_missing_prerequisites_are_named() {
  local missing
  for missing in docker daemon; do
    stack_fixture
    case "$missing" in
      docker) rm "$STUBS/docker" ;;
      daemon) touch "$STUBS/docker-down" ;;
    esac
    expect_fail "$PROJ/bin/up"
    case "$missing" in
      docker) expect_output 'docker is not installed'; expect_output 'bin/doctor' ;;
      daemon) expect_output 'Docker is not running' ;;
    esac
    [ -z "$("$PROJ/bin/session" list)" ] || fail "slot claimed without $missing"
    [ ! -e "$PROJ/.env.session" ] || fail "session file written without $missing"
  done
}

# [dev-sessions-b256e0]
test_unhealthy_stack_keeps_slot_and_shows_logs() {
  stack_fixture
  touch "$STUBS/up-fails"
  echo c0ffee > "$STUBS/ps-ids"
  printf 'postgres running Up 9 seconds (unhealthy)\nother running Up 9 seconds (healthy)\nonce exited Exited (1)\n' > "$STUBS/ps-states"
  expect_fail "$PROJ/bin/up"
  expect_output 'Slot 1 is kept'
  grep -q 'compose .* logs --tail 50 postgres$' "$STUBS/docker.log" || fail 'unhealthy service logs not shown'
  grep -q 'compose .* logs --tail 50 once$' "$STUBS/docker.log" || fail 'exited service logs not shown'
  ! grep -q 'logs --tail 50 other$' "$STUBS/docker.log" || fail 'healthy service logs shown'
  [ -f "$PROJ/.env.session" ] || fail 'session file removed'
  [ "$("$PROJ/bin/session" slot-for "$PROJ")" = 1 ] || fail 'slot released'
}

# [dev-sessions-0ad372]
test_failed_start_without_containers_releases_slot() {
  stack_fixture
  touch "$STUBS/up-fails"
  expect_fail "$PROJ/bin/up"
  expect_output 'slot 1 was released'
  [ ! -e "$PROJ/.env.session" ] || fail 'session file kept'
  ! "$PROJ/bin/session" slot-for "$PROJ" > /dev/null || fail 'slot kept'
}

# A failed start that left volumes keeps the slot instead of orphaning them.
test_failed_start_with_volumes_keeps_slot() {
  stack_fixture
  touch "$STUBS/up-fails"
  echo v1 > "$STUBS/volume-ids"
  expect_fail "$PROJ/bin/up"
  [ -f "$PROJ/.env.session" ] || fail 'session file removed'
  [ "$("$PROJ/bin/session" slot-for "$PROJ")" = 1 ] || fail 'slot released over leftover volumes'
}

# [dev-sessions-5da8d7]
test_stop_keeps_the_session() {
  stack_fixture
  expect_pass "$PROJ/bin/stop"
  expect_output 'nothing to stop'
  [ ! -e "$STUBS/docker.log" ] || fail 'docker called without a session'
  "$PROJ/bin/up" > /dev/null
  expect_pass "$PROJ/bin/stop"
  grep -q 'compose .* stop$' "$STUBS/docker.log" || fail 'stack not stopped'
  [ -f "$PROJ/.env.session" ] || fail 'session file removed'
  [ "$("$PROJ/bin/session" slot-for "$PROJ")" = 1 ] || fail 'slot released'
  ! grep -Eq ' down | rm |volume rm' "$STUBS/docker.log" || fail 'stop removed something'
}

# The lines of the stub's docker log after bin/stop's compose stop.
after_stop() { sed -n '/compose .* stop$/,$p' "$STUBS/docker.log" | tail -n +2; }
polls() { after_stop | grep -c '^docker ps -q --filter label=com.docker.compose.project=factory-1$' || true; }

# [dev-sessions-a29c95]
test_stop_waits_for_a_late_container() {
  stack_fixture
  "$PROJ/bin/up" > /dev/null
  echo 2 > "$STUBS/ps-running"
  expect_pass "$PROJ/bin/stop"
  [ "$(polls)" = 3 ] || fail "expected 3 polls after compose stop, got $(polls)"
  [ "$(cat "$STUBS/ps-running")" = 0 ] || fail 'returned while a container ran'
}

# [dev-sessions-e90f8e]
test_stop_names_a_container_that_keeps_running() {
  stack_fixture
  "$PROJ/bin/up" > /dev/null
  echo 99 > "$STUBS/ps-running"
  printf 'backend (Up 5 minutes): factory-1-backend-1\n' > "$STUBS/ps-states"
  FACTORY_STOP_TIMEOUT=2 expect_fail "$PROJ/bin/stop"
  expect_output 'still running after 2s'
  expect_output $'\nbackend (Up 5 minutes): factory-1-backend-1'
  expect_output 'FACTORY_STOP_TIMEOUT'
  expect_output 'docker stop <name>'
  [ "$(polls)" = 3 ] || fail "expected 3 polls in 2s, got $(polls)"
  after_stop | grep -qxF 'docker ps --filter label=com.docker.compose.project=factory-1 --format {{.Label "com.docker.compose.service"}} ({{.Status}}): {{.Names}}' \
    || fail "the report listed other containers: $(after_stop)"
}

# The last container stops between the final poll and the report.
test_stop_passes_when_the_report_finds_nothing() {
  stack_fixture
  "$PROJ/bin/up" > /dev/null
  echo 99 > "$STUBS/ps-running"
  FACTORY_STOP_TIMEOUT=1 expect_pass "$PROJ/bin/stop"
  [[ "$OUT" != *'still running'* ]] || fail "reported nothing as running: $OUT"
}

test_stop_fails_when_docker_ps_fails() {
  stack_fixture
  "$PROJ/bin/up" > /dev/null
  touch "$STUBS/ps-fails"
  "$PROJ/bin/stop" > /dev/null 2>&1 && fail 'bin/stop passed without seeing the stack stopped'
  [ "$?" = 4 ] || fail 'docker ps status not kept'
}

test_stop_needs_the_project_name() {
  stack_fixture
  "$PROJ/bin/up" > /dev/null
  rm "$STUBS/docker.log"
  sed -i.bak '/^COMPOSE_PROJECT_NAME=/d' "$PROJ/.env.session"
  expect_fail "$PROJ/bin/stop"
  expect_output 'no COMPOSE_PROJECT_NAME'
  ! grep -q 'compose .* stop$' "$STUBS/docker.log" 2> /dev/null || fail 'stopped without a project name'
}

test_stop_of_a_stopped_stack_polls_once() {
  stack_fixture
  "$PROJ/bin/up" > /dev/null
  expect_pass "$PROJ/bin/stop"
  [ "$(polls)" = 1 ] || fail "expected 1 poll, got $(polls)"
}

test_stop_rejects_a_bad_timeout() {
  local value
  stack_fixture
  "$PROJ/bin/up" > /dev/null
  for value in 0 abc 3601 '5 ' 07; do
    rm -f "$STUBS/docker.log"
    FACTORY_STOP_TIMEOUT="$value" expect_fail "$PROJ/bin/stop"
    expect_output "FACTORY_STOP_TIMEOUT must be a whole number of seconds from 1 to 3600, not: $value"
    [ ! -e "$STUBS/docker.log" ] || fail "docker called with FACTORY_STOP_TIMEOUT=$value"
  done
  FACTORY_STOP_TIMEOUT=3600 expect_pass "$PROJ/bin/stop"
}

test_stop_fails_when_compose_stop_fails() {
  stack_fixture
  "$PROJ/bin/up" > /dev/null
  touch "$STUBS/stop-fails"
  "$PROJ/bin/stop" > /dev/null 2>&1 && fail 'bin/stop passed over a failed compose stop'
  [ "$?" = 3 ] || fail 'compose stop status not kept'
  [ "$(polls)" = 0 ] || fail 'polled after a failed compose stop'
}

# Records a running watch for slot 1, as bin/orca-setup leaves it: a worktree
# whose bin/compose watches a path and sleeps.
start_watch() {
  mkdir -p "$REPO/watcher/bin"
  printf '#!/bin/bash\n[ "$1" != config ] || { echo "    develop:"; exit 0; }\necho "Watch enabled"\nsleep 300\n' > "$REPO/watcher/bin/compose"
  chmod +x "$REPO/watcher/bin/compose"
  "$PROJ/bin/session" watch-start 1 "$REPO/watcher" > /dev/null
  WATCH="$(cat "$REPO/registry/watch-1.pid")"
}

# [dev-sessions-070ab5]
test_stop_ends_the_watch() {
  stack_fixture
  "$PROJ/bin/up" > /dev/null
  start_watch
  expect_pass "$PROJ/bin/stop"
  ! kill -0 "$WATCH" 2> /dev/null || { kill -- -"$WATCH"; fail 'watch still running'; }
  [ ! -e "$REPO/registry/watch-1.pid" ] || fail 'watch record left'
  [ -f "$PROJ/.env.session" ] || fail 'session file removed'
  [ "$("$PROJ/bin/session" slot-for "$PROJ")" = 1 ] || fail 'slot released'
}

# [dev-sessions-ae2dd8]
test_logs_pass_flags_through() {
  stack_fixture
  "$PROJ/bin/up" > /dev/null
  expect_pass "$PROJ/bin/logs" postgres -f --since 5m
  tail -n 1 "$STUBS/docker.log" | grep -q 'compose .* logs postgres -f --since 5m$' || fail 'flags changed'
  grep -qx 'COMPOSE_PROJECT_NAME=factory-1' "$STUBS/compose-env" || fail 'wrong project'
}

test_down_removes_everything() {
  local label='label=com.docker.compose.project=factory-1' line
  stack_fixture
  "$PROJ/bin/up" > /dev/null
  start_watch
  echo c1 > "$STUBS/ps-ids"
  echo v1 > "$STUBS/volume-ids"
  echo n1 > "$STUBS/network-ids"
  echo i1 > "$STUBS/image-ids"
  rm "$STUBS/docker.log"
  expect_pass "$PROJ/bin/down"
  expect_output 'Session 1 removed'
  grep -q 'compose .* down -v --remove-orphans$' "$STUBS/docker.log" || fail 'compose down not run'
  for line in "docker ps -aq --filter $label" 'docker rm -f c1' "docker volume ls -q --filter $label" \
    'docker volume rm v1' "docker network ls -q --filter $label" 'docker network rm n1' \
    "docker image ls -q --filter $label" 'docker image rm i1'; do
    grep -qxF "$line" "$STUBS/docker.log" || fail "missing: $line"
  done
  ! grep -v 'factory-1' "$STUBS/docker.log" | grep -q 'filter' || fail 'filtered outside its project'
  ! kill -0 "$WATCH" 2> /dev/null || { kill -- -"$WATCH"; fail 'watch still running'; }
  [ ! -e "$PROJ/.env.session" ] || fail 'session file left'
  ! "$PROJ/bin/session" slot-for "$PROJ" > /dev/null || fail 'slot not released'
}

# [dev-sessions-d05dd0]
test_down_without_session() {
  stack_fixture
  expect_pass "$PROJ/bin/down"
  expect_output 'nothing to tear down'
  [ ! -e "$STUBS/docker.log" ] || fail 'docker called without a session'
}

# [dev-sessions-578c95]
# bin/down never removes a stack whose slot the registry gives another worktree.
test_down_refuses_a_slot_held_by_another_worktree() {
  stack_fixture
  mkdir "$REPO/other"
  "$PROJ/bin/session" claim "$REPO/other" > /dev/null
  printf 'FACTORY_SESSION_ID=1\nCOMPOSE_PROJECT_NAME=factory-1\n' > "$PROJ/.env.session"
  echo c1 > "$STUBS/ps-ids"
  expect_fail "$PROJ/bin/down"
  expect_output 'Slot 1 belongs to'
  ! grep -Eq ' down | rm |volume rm' "$STUBS/docker.log" 2> /dev/null || fail 'removed another worktree'\''s stack'
  [ "$("$PROJ/bin/session" slot-for "$REPO/other")" = 1 ] || fail 'other worktree lost its slot'
}

# [dev-sessions-3e4b5f]
test_down_with_docker_stopped_keeps_the_session() {
  stack_fixture
  "$PROJ/bin/up" > /dev/null
  touch "$STUBS/docker-down"
  expect_fail "$PROJ/bin/down"
  expect_output 'Docker is not running'
  [ -f "$PROJ/.env.session" ] || fail 'session file removed'
  [ "$("$PROJ/bin/session" slot-for "$PROJ")" = 1 ] || fail 'slot released while Docker was down'
}

# A registry wiped after bin/up: the session file still names the project.
test_down_after_a_wiped_registry_removes_by_label() {
  stack_fixture
  "$PROJ/bin/up" > /dev/null
  rm -rf "$REPO/registry"
  echo c1 > "$STUBS/ps-ids"
  expect_pass "$PROJ/bin/down"
  grep -qxF 'docker rm -f c1' "$STUBS/docker.log" || fail 'containers not removed by label'
  [ ! -e "$PROJ/.env.session" ] || fail 'session file left'
}

# [dev-sessions-f6d714]
test_help_needs_nothing() {
  local command
  stack_fixture
  rm "$STUBS/docker"
  for command in session compose up stop down logs seed; do
    expect_pass "$PROJ/bin/$command" --help
    expect_output "Usage: bin/$command"
  done
  [ ! -e "$REPO/registry" ] || fail 'help touched the registry'
}

# [dev-sessions-daaa07]
test_up_reaps_before_claiming() {
  local removed started
  stack_fixture
  export FACTORY_SESSION_SLOTS=1
  mkdir "$REPO/gone"
  "$PROJ/bin/session" claim "$REPO/gone" > /dev/null
  printf 'factory-1\t%s\n' "$(cd "$REPO/gone" && pwd -P)" > "$STUBS/reap-containers"
  rm -rf "$REPO/gone"
  expect_pass "$PROJ/bin/up"
  expect_output 'Removed factory-1'
  grep -qx 'FACTORY_SESSION_ID=1' "$PROJ/.env.session" || fail 'the reaped slot was not reused'
  removed="$(grep -n 'docker network ls -q --filter label=com.docker.compose.project=factory-1$' "$STUBS/docker.log" | cut -d: -f1 | sed -n 1p)"
  started="$(grep -n 'compose .* up -d' "$STUBS/docker.log" | cut -d: -f1)"
  [ -n "$removed" ] && [ "$removed" -lt "$started" ] || fail "not reaped before the stack started: $(cat "$STUBS/docker.log")"
}

# [dev-sessions-02ec45]
test_ci_shellchecks_the_session_scripts() {
  local step script
  step="$(grep -E 'koalaman/shellcheck' "$ROOT/.github/workflows/checks.yml")"
  for script in bin/session bin/compose bin/up bin/stop bin/down bin/logs bin/seed; do
    [[ " $step " == *" $script "* ]] || fail "shellcheck step misses $script"
  done
}

# [dev-sessions-471c88]
test_ci_runs_the_sessions_proof() {
  local job
  job="$(awk '/^  sessions-proof:/ { on = 1; print; next } on && /^  [a-z]/ { exit } on' "$ROOT/.github/workflows/checks.yml")"
  [ -n "$job" ] || fail 'no sessions-proof job'
  grep -q 'run: bin/tests/sessions.e2e.sh$' <<< "$job" || fail 'the job does not run the proof'
  grep -q 'always()' <<< "$job" || fail 'no cleanup step that always runs'
  grep -q 'bin/down' <<< "$job" || fail 'the cleanup step does not run bin/down'
}

# A backend that fails its migration never turns healthy: bin/up fails, shows
# its log and keeps the slot.
test_unhealthy_backend_fails_up_with_its_log() {
  stack_fixture
  touch "$STUBS/up-fails"
  echo c0ffee > "$STUBS/ps-ids"
  printf 'postgres running Up 9 seconds (healthy)\nbackend exited Exited (1)\n' > "$STUBS/ps-states"
  expect_fail "$PROJ/bin/up"
  expect_output 'Slot 1 is kept'
  expect_output '--- last 50 log lines of backend ---'
  grep -q 'compose .* logs --tail 50 backend$' "$STUBS/docker.log" || fail 'backend logs not shown'
  [ "$("$PROJ/bin/session" slot-for "$PROJ")" = 1 ] || fail 'slot released'
}

# [dev-sessions-d71246]
# Build arguments such as the UI's API origin come from the session file, so
# every start rebuilds the images (from cache when nothing changed).
test_up_builds_the_images_on_every_start() {
  stack_fixture
  expect_pass "$PROJ/bin/up"
  expect_pass "$PROJ/bin/up"
  [ "$(grep -c 'compose .* up -d --build ' "$STUBS/docker.log")" = 2 ] || fail "a start did not build: $(cat "$STUBS/docker.log")"
}

# [auth-6d9f8a]
test_up_seeds_the_healthy_stack() {
  local started seeded
  stack_fixture
  expect_pass "$PROJ/bin/up"
  expect_output 'Created: demo@example.com'
  started="$(grep -n 'compose .* up -d' "$STUBS/docker.log" | cut -d: -f1)"
  seeded="$(grep -n 'compose .* exec -T backend bun tooling/seed.ts$' "$STUBS/docker.log" | cut -d: -f1)"
  [ -n "$seeded" ] && [ "$seeded" -gt "$started" ] || fail "not seeded after the stack started: $(cat "$STUBS/docker.log")"
}

test_up_fails_when_seeding_fails() {
  stack_fixture
  touch "$STUBS/seed-fails"
  expect_fail "$PROJ/bin/up"
  expect_output 'the stack is up but seeding failed: run bin/seed to see why'
}

# [auth-c60d80]
test_seed_needs_this_worktrees_stack() {
  stack_fixture
  expect_fail "$PROJ/bin/seed"
  expect_output 'run bin/up'
  [ ! -e "$STUBS/docker.log" ] || fail "Docker was called without a stack: $(cat "$STUBS/docker.log")"
  write_session
  touch "$STUBS/started" "$STUBS/no-backend"
  expect_fail "$PROJ/bin/seed"
  expect_output 'the backend is not running — run bin/up'
  if grep -q ' exec ' "$STUBS/docker.log"; then fail 'seeded without a running backend'; fi
}

test_seed_runs_in_the_backend() {
  stack_fixture
  write_session
  touch "$STUBS/started"
  expect_pass "$PROJ/bin/seed"
  expect_output 'Created: demo@example.com'
  grep -q 'compose .* exec -T backend bun tooling/seed.ts$' "$STUBS/docker.log" || fail "seed not run in the backend: $(cat "$STUBS/docker.log")"
}

test_seed_help_names_the_demo_user() {
  stack_fixture
  expect_pass "$PROJ/bin/seed" --help
  expect_output 'demo@example.com'
  expect_output 'password'
}
