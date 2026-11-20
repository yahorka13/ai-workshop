# shellcheck shell=bash disable=SC2154
# bin/tests/stack-report.sh against fake compose and docker commands.

# fake_stack <services>: a compose that lists the services, one container each.
fake_stack() {
  mkdir -p "$REPO/fakes"
  cat > "$REPO/fakes/compose" <<'COMPOSE'
#!/usr/bin/env bash
case "$*" in
  "ps -a --format {{.Service}}") printf '%s\n' $SERVICES ;;
  "ps -aq") for s in $SERVICES; do echo "id-$s"; done ;;
  "logs --no-color --timestamps "*) echo "log of ${*: -1}" ;;
  *) exit 2 ;;
esac
COMPOSE
  cat > "$REPO/fakes/docker" <<'DOCKER'
#!/usr/bin/env bash
[ "$1" = inspect ] && echo "/${*: -1} status=running exit=0 restarts=0 oom=false"
DOCKER
  chmod +x "$REPO/fakes/compose" "$REPO/fakes/docker"
  export PATH="$REPO/fakes:$PATH" SERVICES="$1"
  # shellcheck source=bin/tests/stack-report.sh
  source "$ROOT/bin/tests/stack-report.sh"
}

test_stack_report_shows_each_container_and_keeps_logs() {
  fake_stack 'backend ui'
  expect_pass stack_report "$REPO/fakes/compose" "$REPO/out"
  expect_output '== stack state =='
  expect_output '/id-ui status=running'
  expect_output 'log of backend'
  grep -qx 'log of ui' "$REPO/out/logs/ui.log" || fail 'no ui log kept'
}

test_stack_report_never_fails_without_containers() {
  fake_stack ''
  expect_pass stack_report "$REPO/fakes/compose" "$REPO/out"
  expect_output 'no containers to report'
  expect_pass stack_report "$REPO/no-such-compose" "$REPO/out"
}
