# shellcheck shell=bash disable=SC2154,SC2034
# Slot registry tests. Stub ss and lsof report the ports listed in $STUBS/listening.
# [dev-sessions-8ae377] These tests run unchanged on macOS and in the Linux CI runner.
session_fixture() {
  STUBS="$REPO/stubs"
  rm -rf "$STUBS" "$REPO/registry"
  mkdir -p "$STUBS" "$REPO/wt1" "$REPO/wt2" "$REPO/wt 3"
  export FACTORY_SESSION_REGISTRY="$REPO/registry" FACTORY_LOCK_TIMEOUT=10
  unset FACTORY_SESSION_SLOTS
  cat > "$STUBS/lsof" <<'STUB'
#!/bin/sh
dir="$(cd "$(dirname "$0")" && pwd)"
echo 'COMMAND PID USER FD TYPE DEVICE SIZE/OFF NODE NAME'
[ -f "$dir/listening" ] || exit 0
while read -r port; do
  echo "proc 1 user 3u IPv4 0 0t0 TCP 127.0.0.1:$port (LISTEN)"
done < "$dir/listening"
STUB
  # No leftover Compose projects unless a test says so.
  printf '#!/bin/sh\nexit 0\n' > "$STUBS/docker"
  # The probe asks ss first, so ss reports the same ports (CI runners have a real one).
  cat > "$STUBS/ss" <<'STUB'
#!/bin/sh
dir="$(cd "$(dirname "$0")" && pwd)"
[ -f "$dir/listening" ] || exit 0
while read -r port; do
  echo "LISTEN 0 4096 127.0.0.1:$port 0.0.0.0:*"
done < "$dir/listening"
STUB
  chmod +x "$STUBS/lsof" "$STUBS/docker" "$STUBS/ss"
  export PATH="$STUBS:$PATH"
  SESSION="$ROOT/bin/session"
}

real() { (cd "$1" && pwd -P); }

# [dev-sessions-52a056]
test_repeated_claim_returns_same_slot() {
  session_fixture
  ln -s "$REPO/wt1" "$REPO/link"
  [ "$("$SESSION" claim "$REPO/wt1")" = 1 ] || fail 'first claim'
  [ "$("$SESSION" claim "$REPO/link")" = 1 ] || fail 'symlinked path got another slot'
  [ "$("$SESSION" list | wc -l | tr -d ' ')" = 1 ] || fail 'duplicate registry entries'
}

# [dev-sessions-13071c]
# The second worktree has a path with a space.
test_next_worktree_gets_next_slot() {
  session_fixture
  "$SESSION" claim "$REPO/wt1" > /dev/null
  [ "$("$SESSION" claim "$REPO/wt 3")" = 2 ] || fail 'second worktree'
  [ "$("$SESSION" list | awk -F '\t' '$1 == 2 { print $2 }')" = "$(real "$REPO/wt 3")" ] \
    || fail 'path with a space not recorded whole'
}

# [dev-sessions-c9840d]
test_concurrent_claims_get_distinct_slots() {
  local i
  session_fixture
  export FACTORY_SESSION_SLOTS=5
  for i in 1 2 3 4 5; do
    mkdir "$REPO/c$i"
    "$SESSION" claim "$REPO/c$i" > "$REPO/c$i.slot" 2>&1 &
  done
  wait
  [ "$(cat "$REPO"/c*.slot | sort -u | wc -l | tr -d ' ')" = 5 ] \
    || fail "claims collided: $(cat "$REPO"/c*.slot)"
}

# [dev-sessions-2d3049]
# A deleted holder whose stack is left is listed as stale.
test_exhausted_slots_list_holders() {
  local gone
  session_fixture
  export FACTORY_SESSION_SLOTS=2
  gone="$(real "$REPO/wt2")"
  "$SESSION" claim "$REPO/wt1" > /dev/null
  "$SESSION" claim "$REPO/wt2" > /dev/null
  rm -rf "$REPO/wt2"
  printf '#!/bin/sh\n[ "$*" != "volume ls -q --filter label=com.docker.compose.project=factory-2" ] || echo leftover\n' > "$STUBS/docker"
  expect_fail "$SESSION" claim "$REPO/wt 3"
  expect_output 'no free session slot'
  expect_output "$(printf '1\t%s\talive' "$(real "$REPO/wt1")")"
  expect_output "$(printf '2\t%s\tstale' "$gone")"
  expect_output 'bin/down'
  expect_output 'bin/session reap'
  [[ "$OUT" != *'docker compose'* ]] || fail "still prints a docker compose command: $OUT"
}

# [dev-sessions-b52a96]
test_slot_limit_out_of_range() {
  local value
  for value in 0 11 abc -1 '3 '; do
    session_fixture
    export FACTORY_SESSION_SLOTS="$value"
    expect_fail "$SESSION" claim "$REPO/wt1"
    expect_output 'from 1 to 10'
  done
  session_fixture
  expect_fail "$SESSION" claim "$REPO/missing"
  expect_output 'existing worktree directory'
}

# [dev-sessions-f73589]
test_default_is_three_slots() {
  session_fixture
  mkdir "$REPO/wt4"
  "$SESSION" claim "$REPO/wt1" > /dev/null
  "$SESSION" claim "$REPO/wt2" > /dev/null
  [ "$("$SESSION" claim "$REPO/wt 3")" = 3 ] || fail 'third claim'
  expect_fail "$SESSION" claim "$REPO/wt4"
  expect_output 'all 3 are in use'
  FACTORY_SESSION_SLOTS=01 expect_fail "$SESSION" claim "$REPO/wt4"
}

# [dev-sessions-c815af]
test_deleted_worktree_slot_is_reclaimed() {
  local gone
  session_fixture
  gone="$(real "$REPO/wt1")"
  "$SESSION" claim "$REPO/wt1" > /dev/null
  rm -rf "$REPO/wt1"
  [ "$("$SESSION" list)" = "$(printf '1\t%s\tstale' "$gone")" ] || fail 'stale holder not listed'
  [ "$("$SESSION" claim "$REPO/wt2")" = 1 ] || fail 'stale slot not reclaimed'
  ! "$SESSION" list | grep -qF "$gone" || fail 'deleted path still listed'
}

# [dev-sessions-f0bf93]
test_release_keeps_another_holders_slot() {
  session_fixture
  "$SESSION" claim "$REPO/wt1" > /dev/null
  expect_pass "$SESSION" release 1 "$REPO/wt2"
  expect_output 'leaving it claimed'
  [ "$("$SESSION" slot-for "$REPO/wt1")" = 1 ] || fail 'released a slot held by another worktree'
  expect_pass "$SESSION" release 1 "$REPO/wt1"
  expect_fail "$SESSION" slot-for "$REPO/wt1"
}

# [dev-sessions-18a82b]
# Leading zeros are decimal.
test_ports_follow_the_slot() {
  session_fixture
  [ "$("$SESSION" ports 1)" = $'FACTORY_PORT_UI=10100\nFACTORY_PORT_API=10101\nFACTORY_PORT_POSTGRES=10102' ] || fail 'slot 1'
  [ "$("$SESSION" ports 2)" = $'FACTORY_PORT_UI=11100\nFACTORY_PORT_API=11101\nFACTORY_PORT_POSTGRES=11102' ] || fail 'slot 2'
  [ "$("$SESSION" ports 08)" = $'FACTORY_PORT_UI=17100\nFACTORY_PORT_API=17101\nFACTORY_PORT_POSTGRES=17102' ] || fail 'slot 08'
  [ "$("$SESSION" ports 10)" = $'FACTORY_PORT_UI=19100\nFACTORY_PORT_API=19101\nFACTORY_PORT_POSTGRES=19102' ] || fail 'slot 10'
  expect_fail "$SESSION" ports 11
  expect_fail "$SESSION" ports 0
}

# [dev-sessions-4789dd]
# A worktree whose own stack listens keeps its slot.
test_busy_port_block_is_skipped() {
  session_fixture
  echo 10100 > "$STUBS/listening"
  [ "$("$SESSION" claim "$REPO/wt1")" = 2 ] || fail 'busy block claimed'
  echo 11100 >> "$STUBS/listening"
  [ "$("$SESSION" claim "$REPO/wt1")" = 2 ] || fail 'own listening stack moved to another slot'
}




# [dev-sessions-a48010]
test_busy_postgres_port_skips_the_slot() {
  session_fixture
  echo 10102 > "$STUBS/listening"
  [ "$("$SESSION" claim "$REPO/wt1")" = 2 ] || fail 'busy Postgres port claimed'
}

# [dev-sessions-ccd8c1]
test_dead_holders_lock_is_broken() {
  local dead
  session_fixture
  sleep 0 &
  dead=$!
  wait "$dead"
  mkdir -p "$REPO/registry/.lock.d"
  echo "$dead $(hostname)" > "$REPO/registry/.lock.d/owner"
  expect_pass "$SESSION" claim "$REPO/wt1"
  expect_output "breaking the session lock held by pid $dead"
  [ ! -d "$REPO/registry/.lock.d" ] || fail 'lock left behind'
}

# [dev-sessions-b57a4e]
test_live_holders_lock_times_out() {
  session_fixture
  export FACTORY_LOCK_TIMEOUT=1
  mkdir -p "$REPO/registry/.lock.d"
  echo "$$ $(hostname)" > "$REPO/registry/.lock.d/owner"
  expect_fail "$SESSION" claim "$REPO/wt1"
  expect_output "held by pid $$"
  [ -d "$REPO/registry/.lock.d" ] || fail 'live lock was broken'
}

# [dev-sessions-bf4071]
# A slot whose project still has containers or volumes (a worktree removed
# without bin/down) is skipped, so a new worktree never starts on its data.
test_slot_with_leftover_resources_is_skipped() {
  session_fixture
  cat > "$STUBS/docker" <<'STUB'
#!/bin/sh
case "$*" in
  *'volume ls -q --filter label=com.docker.compose.project=factory-1') echo leftover-volume ;;
esac
exit 0
STUB
  chmod +x "$STUBS/docker"
  [ "$("$SESSION" claim "$REPO/wt1")" = 2 ] || fail 'slot with leftover volumes was claimed'
  [ "$("$SESSION" claim "$REPO/wt1")" = 2 ] || fail 're-claim changed the slot'
}

# A dead holder's lock is broken even if the host was renamed since (macOS
# renames itself on network changes).
test_dead_lock_is_broken_after_hostname_change() {
  local dead
  session_fixture
  sleep 0 &
  dead=$!
  wait "$dead"
  mkdir -p "$REPO/registry/.lock.d"
  echo "$dead old-name.local" > "$REPO/registry/.lock.d/owner"
  expect_pass "$SESSION" claim "$REPO/wt1"
  expect_output "breaking the session lock held by pid $dead"
}

# Only one claimer breaks a dead lock; one already breaking it is left alone,
# so two claims can never both remove a lock and both enter.
test_lock_being_broken_by_another_claim_is_left_alone() {
  local dead
  session_fixture
  export FACTORY_LOCK_TIMEOUT=1
  sleep 0 &
  dead=$!
  wait "$dead"
  mkdir -p "$REPO/registry/.lock.d" "$REPO/registry/.lock.d.break"
  echo "$dead $(hostname)" > "$REPO/registry/.lock.d/owner"
  expect_fail "$SESSION" claim "$REPO/wt1"
  expect_output "pid $dead"
  [ -d "$REPO/registry/.lock.d" ] || fail 'lock removed while another claim was breaking it'
}

# ss sees every user's sockets (docker-proxy runs as root); lsof as a normal
# user does not, so ss is asked first.
test_ss_is_preferred_over_lsof() {
  session_fixture
  printf '#!/bin/sh\necho "LISTEN 0 4096 127.0.0.1:10100 0.0.0.0:*"\n' > "$STUBS/ss"
  printf '#!/bin/sh\necho "COMMAND PID USER FD TYPE DEVICE SIZE/OFF NODE NAME"\n' > "$STUBS/lsof"
  [ "$("$SESSION" claim "$REPO/wt1")" = 2 ] || fail 'port seen only by ss was claimed'
}

# remove-project removes everything labelled with the slot's project, its
# images included, and nothing else.
test_remove_project_removes_by_label() {
  session_fixture
  cat > "$STUBS/docker" <<'STUB'
#!/bin/sh
dir="$(cd "$(dirname "$0")" && pwd)"
echo "docker $*" >> "$dir/docker.log"
case "$*" in
  'ps -aq --filter label=com.docker.compose.project=factory-3') echo container-3 ;;
  'volume ls -q --filter label=com.docker.compose.project=factory-3') echo volume-3 ;;
  'network ls -q --filter label=com.docker.compose.project=factory-3') echo network-3 ;;
  'image ls -q --filter label=com.docker.compose.project=factory-3') printf 'image-3\nimage-3b\n' ;;
esac
exit 0
STUB
  expect_pass "$SESSION" remove-project 3
  grep -qx 'docker rm -f container-3' "$STUBS/docker.log" || fail 'containers not removed'
  grep -qx 'docker volume rm volume-3' "$STUBS/docker.log" || fail 'volumes not removed'
  grep -qx 'docker network rm network-3' "$STUBS/docker.log" || fail 'networks not removed'
  grep -qx 'docker image rm image-3 image-3b' "$STUBS/docker.log" || fail "images not removed: $(cat "$STUBS/docker.log")"
  ! grep -E 'factory-[0-9]' "$STUBS/docker.log" | grep -qv 'factory-3$' || fail 'another project was touched'
  expect_fail "$SESSION" remove-project 11
  expect_output 'from 1 to 10'
}

# A docker that answers reap's discovery from $STUBS/containers (project<TAB>dir
# lines) and $STUBS/volumes (project lines), lists $STUBS/images
# (repository:tag<TAB>created lines), says an image in $STUBS/used has a
# container, logs every call, and is not running when $STUBS/docker-down exists.
reap_fixture() {
  session_fixture
  : > "$STUBS/containers"
  : > "$STUBS/volumes"
  cat > "$STUBS/docker" <<'STUB'
#!/bin/sh
dir="$(cd "$(dirname "$0")" && pwd)"
echo "docker $*" >> "$dir/docker.log"
case "$*" in
  info) [ ! -f "$dir/docker-down" ] ;;
  'ps -a --filter label=com.docker.compose.project --format '*) cat "$dir/containers" ;;
  'volume ls --filter label=com.docker.compose.project --format '*) cat "$dir/volumes" ;;
  'ps -aq --filter label=com.docker.compose.project='*)
    awk -F '\t' -v p="${4#label=com.docker.compose.project=}" '$1 == p { print "c-" NR }' "$dir/containers" ;;
  'volume ls -q --filter label=com.docker.compose.project='*)
    awk -v p="${5#label=com.docker.compose.project=}" '$1 == p { print "v-" NR }' "$dir/volumes" ;;
  # Each project's image, whose removal shows the project was removed.
  'image ls -q --filter label=com.docker.compose.project='*) echo "image-${5#label=com.docker.compose.project=}" ;;
esac
STUB
  chmod +x "$STUBS/docker"
}

removed() { grep -qx "docker image rm image-$1" "$STUBS/docker.log"; }

# [dev-sessions-27f723]
# The worktree path has a space.
test_deleted_worktrees_stack_is_reaped() {
  local gone
  reap_fixture
  gone="$(real "$REPO/wt 3")"
  [ "$("$SESSION" claim "$REPO/wt 3")" = 1 ] || fail 'claim'
  printf 'factory-1\t%s\n' "$gone" > "$STUBS/containers"
  rm -rf "$REPO/wt 3"
  expect_pass "$SESSION" reap
  expect_output "Removed factory-1, left by $gone."
  removed factory-1 || fail "factory-1 not removed: $(cat "$STUBS/docker.log")"
  grep -q '^docker rm -f c-1$' "$STUBS/docker.log" || fail "containers kept: $(cat "$STUBS/docker.log")"
  [ -z "$("$SESSION" list)" ] || fail 'slot still held'
}


# [dev-sessions-af5011]
# Containers that name an existing directory keep their stack, whatever the
# registry says.
test_live_worktrees_stack_is_kept() {
  reap_fixture
  "$SESSION" claim "$REPO/wt2" > /dev/null
  rm -rf "$REPO/wt2"
  printf 'factory-1\t%s\nfactory-2\t%s\n' "$(real "$REPO/wt1")" "$(real "$REPO/wt 3")" > "$STUBS/containers"
  expect_pass "$SESSION" reap
  ! grep -qE '^docker (rm|volume rm|network rm|image rm)' "$STUBS/docker.log" || fail "a live stack was removed: $(cat "$STUBS/docker.log")"
  "$SESSION" list | grep -q '^1	' || fail 'slot 1 freed while its project serves a live worktree'
}

# No slot names the project: it is traced by its containers alone.
test_unregistered_project_of_a_deleted_worktree_is_reaped() {
  local gone
  reap_fixture
  mkdir "$REPO/gone"
  gone="$(real "$REPO/gone")"
  printf 'factory-5\t%s\n' "$gone" > "$STUBS/containers"
  rm -rf "$REPO/gone"
  expect_pass "$SESSION" reap
  expect_output "Removed factory-5, left by $gone."
  removed factory-5 || fail "factory-5 not removed: $(cat "$STUBS/docker.log")"
}

# A project with only volumes that no slot names cannot be traced to a worktree.
test_unregistered_volume_only_project_is_kept() {
  reap_fixture
  echo factory-4 > "$STUBS/volumes"
  expect_pass "$SESSION" reap
  ! removed factory-4 || fail 'unregistered volumes removed'
}

test_registered_project_without_containers_is_reaped() {
  reap_fixture
  "$SESSION" claim "$REPO/wt2" > /dev/null
  echo factory-1 > "$STUBS/volumes"
  rm -rf "$REPO/wt2"
  expect_pass "$SESSION" reap
  removed factory-1 || fail "factory-1 not removed: $(cat "$STUBS/docker.log")"
  [ -z "$("$SESSION" list)" ] || fail 'slot still held'
}

# Several bin/up runs on one machine share the Docker daemon and the registry,
# so each reaps the same deleted worktree's stack at once.
slow_removal_stub() {
  cat > "$STUBS/docker" <<'STUB'
#!/bin/sh
dir="$(cd "$(dirname "$0")" && pwd)"
echo "docker $*" >> "$dir/docker.log"
case "$*" in
  info) exit 0 ;;
  'ps -a --filter label=com.docker.compose.project --format '*) cat "$dir/containers" ;;
  'volume ls --filter label=com.docker.compose.project --format '*) cat "$dir/volumes" ;;
  'ps -aq --filter label=com.docker.compose.project='*)
    awk -F '\t' -v p="${4#label=com.docker.compose.project=}" '$1 == p { print "c-" NR }' "$dir/containers" ;;
  'rm -f '*) : > "$dir/containers"; sleep 2 ;;
  'image ls -q --filter label=com.docker.compose.project='*) echo "image-${5#label=com.docker.compose.project=}" ;;
  'image rm '*) sleep 2 ;;
esac
STUB
}

test_concurrent_reaps_remove_a_stack_once() {
  local gone
  reap_fixture
  slow_removal_stub
  gone="$(real "$REPO/wt1")"
  "$SESSION" claim "$REPO/wt1" > /dev/null
  printf 'factory-1\t%s\n' "$gone" > "$STUBS/containers"
  rm -rf "$REPO/wt1"
  "$SESSION" reap > "$REPO/reap-1.log" 2>&1 & local one=$!
  "$SESSION" reap > "$REPO/reap-2.log" 2>&1 & local two=$!
  wait "$one" || fail "first reap failed: $(cat "$REPO/reap-1.log")"
  wait "$two" || fail "second reap failed: $(cat "$REPO/reap-2.log")"
  [ "$(grep -c '^docker rm -f' "$STUBS/docker.log")" = 1 ] || fail "the stack was removed twice: $(cat "$STUBS/docker.log")"
  [ -z "$("$SESSION" list)" ] || fail 'slot still held'
}

# bin/up claims right after its reap: a reap that left a stack to another
# one must still return only once that stack is gone and its slot free.
test_reap_waits_for_a_removal_another_reap_runs() {
  reap_fixture
  slow_removal_stub
  "$SESSION" claim "$REPO/wt1" > /dev/null
  printf 'factory-1\t%s\n' "$(real "$REPO/wt1")" > "$STUBS/containers"
  rm -rf "$REPO/wt1"
  "$SESSION" reap > "$REPO/reap-1.log" 2>&1 & local first=$!
  until grep -q '^docker rm -f' "$STUBS/docker.log" 2> /dev/null; do sleep 0.1; done
  expect_pass "$SESSION" reap
  [ "$("$SESSION" claim "$REPO/wt2")" = 1 ] || fail 'slot 1 not free once the second reap returned'
  wait "$first" || fail "first reap failed: $(cat "$REPO/reap-1.log")"
}

test_reap_tolerates_a_removal_already_in_progress() {
  local gone
  reap_fixture
  gone="$(real "$REPO/wt1")"
  "$SESSION" claim "$REPO/wt1" > /dev/null
  printf 'factory-1\t%s\n' "$gone" > "$STUBS/containers"
  rm -rf "$REPO/wt1"
  # Another process, such as a cancelled job's bin/down, removes it first.
  sed -i.bak "s|^esac|  'rm -f '*) : > \"\$dir/containers\"; echo 'Error response from daemon: removal of container c-1 is already in progress' >\&2; exit 1 ;;\nesac|" "$STUBS/docker"
  expect_pass "$SESSION" reap
  [ -z "$("$SESSION" list)" ] || fail 'slot still held'
}

test_reap_fails_when_containers_survive_removal() {
  reap_fixture
  "$SESSION" claim "$REPO/wt1" > /dev/null
  printf 'factory-1\t%s\n' "$(real "$REPO/wt1")" > "$STUBS/containers"
  rm -rf "$REPO/wt1"
  sed -i.bak "s|^esac|  'rm -f '*) exit 1 ;;\nesac|" "$STUBS/docker"
  FACTORY_REMOVE_TIMEOUT=1 expect_fail "$SESSION" reap
  expect_output 'factory-1 still has containers'
}

test_claim_skips_a_slot_being_reaped() {
  local slot
  reap_fixture
  slow_removal_stub
  "$SESSION" claim "$REPO/wt1" > /dev/null
  printf 'factory-1\t%s\n' "$(real "$REPO/wt1")" > "$STUBS/containers"
  rm -rf "$REPO/wt1"
  "$SESSION" reap > "$REPO/reap.log" 2>&1 & local reaper=$!
  # The containers are gone at once; the reap is still removing images.
  until grep -q '^docker rm -f' "$STUBS/docker.log" 2> /dev/null; do sleep 0.1; done
  slot="$("$SESSION" claim "$REPO/wt2")"
  wait "$reaper" || fail "reap failed: $(cat "$REPO/reap.log")"
  [ "$slot" = 2 ] || fail "claimed slot $slot while it was being reaped"
}

# [dev-sessions-67961b]
test_reap_without_docker_changes_nothing() {
  reap_fixture
  "$SESSION" claim "$REPO/wt1" > /dev/null
  printf 'factory-1\t%s\n' "$(real "$REPO/wt1")" > "$STUBS/containers"
  rm -rf "$REPO/wt1"
  touch "$STUBS/docker-down"
  expect_pass "$SESSION" reap
  expect_output 'Docker is not available'
  ! removed factory-1 || fail 'removed without Docker'
  "$SESSION" list | grep -q '^1	' || fail 'slot freed without Docker'
}

# A worktree whose bin/compose stub logs to $STUBS/compose.log, announces and
# sleeps for `watch`, exits 5 at once with $STUBS/compose-fails or after 2s with
# compose-fails-late, and never announces with compose-silent.
watch_fixture() {
  session_fixture
  export HOME="$REPO/home"
  WATCH_LOG="$HOME/.factory/orca-watch-1.log"
  watch_stub "$REPO/wt1"
}

watch_stub() {
  mkdir -p "$1/bin"
  cat > "$1/bin/compose" <<STUB
#!/bin/bash
S="$STUBS"
STUB
  cat >> "$1/bin/compose" <<'STUB'
echo "compose $* in $PWD" >> "$S/compose.log"
if [ "$1" = config ]; then
  [ -f "$S/no-develop" ] || printf 'services:\n  app:\n    develop:\n      watch: []\n'
  exit 0
fi
[ ! -f "$S/compose-fails" ] || { echo 'compose failed' >&2; exit 5; }
[ ! -f "$S/compose-fails-late" ] || { sleep 2; echo 'compose failed late' >&2; exit 5; }
[ "$1" != watch ] || [ -f "$S/compose-silent" ] || echo 'Watch enabled'
[ "$1" != watch ] || sleep 300
STUB
  chmod +x "$1/bin/compose"
}

watch_pid() { cat "$FACTORY_SESSION_REGISTRY/watch-$1.pid" 2> /dev/null; }
alive() { kill -0 "$1" 2> /dev/null; }

# [dev-sessions-6834b6]
test_watch_start_runs_and_logs() {
  local pid
  watch_fixture
  expect_pass "$SESSION" watch-start 1 "$REPO/wt1"
  expect_output "$WATCH_LOG"
  pid="$(watch_pid 1)"
  { [ -n "$pid" ] && alive "$pid"; } || fail 'no live watch recorded'
  for _ in $(seq 50); do ! grep -q 'Watch enabled' "$WATCH_LOG" 2> /dev/null || break; sleep 0.1; done
  grep -qx 'Watch enabled' "$WATCH_LOG" || fail 'watch output not logged'
  grep -qx "compose watch in $(real "$REPO/wt1")" "$STUBS/compose.log" || fail "$(cat "$STUBS/compose.log")"
  "$SESSION" watch-stop 1
}

# [dev-sessions-e6c033]
test_watch_start_replaces_the_watch() {
  local first second
  watch_fixture
  "$SESSION" watch-start 1 "$REPO/wt1" > /dev/null
  first="$(watch_pid 1)"
  "$SESSION" watch-start 1 "$REPO/wt1" > /dev/null
  second="$(watch_pid 1)"
  [ "$first" != "$second" ] || fail 'watch not replaced'
  ! alive "$first" || fail 'first watch still running'
  alive "$second" || fail 'second watch not running'
  "$SESSION" watch-stop 1
  ! alive "$second" || fail 'watch-stop left the watch'
  [ -z "$(pgrep -f "$REPO/wt1/bin/compose watch" || true)" ] || fail 'a watch process is left'
  [ ! -e "$FACTORY_SESSION_REGISTRY/watch-1.pid" ] || fail 'record left'
}

# On a loaded host the watch's process still runs the forking shell when
# watch-start first looks at it: a watch on its way is not one that exited.
test_watch_start_waits_for_the_watch_to_exec() {
  watch_fixture
  cat > "$STUBS/ps" <<'STUB'
#!/bin/sh
dir="$(cd "$(dirname "$0")" && pwd)"
if [ "$1 $2" = '-o args=' ] && [ ! -f "$dir/exec-seen" ]; then
  touch "$dir/exec-seen"
  echo 'bash bin/session watch-start'
  exit 0
fi
exec /bin/ps "$@"
STUB
  chmod +x "$STUBS/ps"
  expect_pass "$SESSION" watch-start 1 "$REPO/wt1"
  "$SESSION" watch-stop 1
}

# [dev-sessions-f6e826]
test_recycled_pid_is_left_alone() {
  local other
  watch_fixture
  # Not a job of this shell, so killing it prints no notice.
  other="$(sh -c 'sleep 300 > /dev/null 2>&1 & echo $!')"
  mkdir -p "$FACTORY_SESSION_REGISTRY"
  echo "$other" > "$FACTORY_SESSION_REGISTRY/watch-1.pid"
  expect_pass "$SESSION" watch-stop 1
  alive "$other" || fail 'another process was signalled'
  kill "$other"
  [ ! -e "$FACTORY_SESSION_REGISTRY/watch-1.pid" ] || fail 'record left'
}

test_watch_stop_forgets_a_dead_watch() {
  local gone
  watch_fixture
  sh -c 'exit 0' &
  gone=$!
  wait "$gone"
  mkdir -p "$FACTORY_SESSION_REGISTRY"
  echo "$gone" > "$FACTORY_SESSION_REGISTRY/watch-1.pid"
  expect_pass "$SESSION" watch-stop 1
  [ ! -e "$FACTORY_SESSION_REGISTRY/watch-1.pid" ] || fail 'record left'
  expect_pass "$SESSION" watch-stop 2
}

# [dev-sessions-80e03e]
test_watch_start_failure_exits_nonzero() {
  local marker
  for marker in compose-fails compose-fails-late; do
    watch_fixture
    touch "$STUBS/$marker"
    expect_fail "$SESSION" watch-start 1 "$REPO/wt1"
    expect_output "$WATCH_LOG"
    [ ! -e "$FACTORY_SESSION_REGISTRY/watch-1.pid" ] || fail "record left ($marker)"
    grep -q 'compose failed' "$WATCH_LOG" || fail "failure not logged ($marker)"
  done
}

# [dev-sessions-80e03e]
# A watch that never says it is watching is stopped, not recorded.
test_watch_start_times_out_without_the_banner() {
  watch_fixture
  touch "$STUBS/compose-silent"
  expect_fail env FACTORY_WATCH_START_TIMEOUT=2 "$SESSION" watch-start 1 "$REPO/wt1"
  expect_output 'did not start watching within 2s'
  [ ! -e "$FACTORY_SESSION_REGISTRY/watch-1.pid" ] || fail 'record left'
  [ -z "$(pgrep -f "$REPO/wt1/bin/compose watch" || true)" ] || fail 'silent watch left running'
}

# An earlier run's banner in the appended log does not count for a new watch.
test_watch_start_ignores_an_old_banner() {
  watch_fixture
  mkdir -p "$(dirname "$WATCH_LOG")"
  echo 'Watch enabled' > "$WATCH_LOG"
  touch "$STUBS/compose-fails-late"
  expect_fail "$SESSION" watch-start 1 "$REPO/wt1"
  [ ! -e "$FACTORY_SESSION_REGISTRY/watch-1.pid" ] || fail 'record left'
}

# [dev-sessions-afe93a]
test_reap_stops_a_deleted_worktrees_watch() {
  local pid gone
  reap_fixture
  export HOME="$REPO/home"
  gone="$(real "$REPO/wt 3")"
  [ "$("$SESSION" claim "$REPO/wt 3")" = 1 ] || fail 'claim'
  watch_stub "$REPO/wt 3"
  "$SESSION" watch-start 1 "$REPO/wt 3" > /dev/null
  pid="$(watch_pid 1)"
  printf 'factory-1\t%s\n' "$gone" > "$STUBS/containers"
  rm -rf "$REPO/wt 3"
  expect_pass "$SESSION" reap
  ! alive "$pid" || { kill -- -"$pid"; fail 'watch of a deleted worktree left running'; }
  [ ! -e "$FACTORY_SESSION_REGISTRY/watch-1.pid" ] || fail 'record left'
}

# [dev-sessions-1f72de]
test_nothing_to_watch_starts_no_watch() {
  watch_fixture
  touch "$STUBS/no-develop"
  expect_pass "$SESSION" watch-start 1 "$REPO/wt1"
  expect_output 'Nothing to watch'
  [ ! -e "$FACTORY_SESSION_REGISTRY/watch-1.pid" ] || fail 'a watch was recorded'
  ! grep -q 'compose watch' "$STUBS/compose.log" || fail "a watch was started: $(cat "$STUBS/compose.log")"
}
