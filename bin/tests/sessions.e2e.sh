#!/usr/bin/env bash
# Docker-backed proof that worktrees run isolated stacks side by side, that
# bin/stop keeps a stack's data, that a watch reaches its container, that
# bin/down removes a stack and that bin/up reaps a deleted worktree's. Not a
# fast test: CI runs it in the sessions-proof job.
set -euo pipefail
if [ "$#" -eq 1 ] && [ "$1" = --help ]; then
  cat <<'HELP'
usage: bin/tests/sessions.e2e.sh

Requires Docker with Compose 2.22 or newer, git and three free session slots
(FACTORY_SESSION_SLOTS). Copies this checkout's files, without .env, into
worktrees with spaces in their paths under tmp/sessions-proof/, then:
  - runs bin/up in two of them at once, checks their isolation and that each
    backend answers /health and the GraphQL health query, each serves its UI,
    and each API allows CORS from its own UI only;
  - bin/stop and bin/up keep a row and the slot;
  - adds a small watched service to one copy and shows bin/up --watch syncing
    an edited file into its container, and watch-start keeping one watch;
  - bin/down in one leaves the other running and nothing of its own;
  - deletes a worktree with its stack running and shows the next bin/up in a
    new worktree removes that stack.
Prints PASS lines and a TIME line per start; removes every stack at the end.
Logs remain in tmp/sessions-proof/.
HELP
  exit 0
fi
[ "$#" -eq 0 ] || { echo 'Use --help for usage' >&2; exit 2; }
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
mkdir -p "$root/tmp/sessions-proof"
output="$(mktemp -d "$root/tmp/sessions-proof/run.XXXXXX")"
a="$output/worktree a"
b="$output/worktree b"
c="$output/worktree c"
watch_pid=""
unset FACTORY_PUBLIC_HOST FACTORY_BIND_HOST COMPOSE_PROJECT_NAME

cleanup() {
  local status=$? wt
  trap - EXIT INT TERM
  [ -z "$watch_pid" ] || kill "$watch_pid" 2> /dev/null || true
  for wt in "$a" "$b" "$c"; do
    [ ! -x "$wt/bin/down" ] || "$wt/bin/down" >> "$output/cleanup.log" 2>&1 || true
  done
  # A worktree deleted by the test leaves its stack to reap.
  "$root/bin/session" reap >> "$output/cleanup.log" 2>&1 || true
  echo "E2E artifacts: $output"
  exit "$status"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

fail() { echo "FAIL: $*; see $output" >&2; exit 1; }
pass() { echo "PASS: $*"; }
value() { sed -n "s/^$2=//p" "$1/.env.session"; }
# shellcheck disable=SC2016 # expanded by the shell inside the container
psql_in() { "$1/bin/compose" exec -T postgres sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tAc "$1"' psql "$2"; }
labelled() { docker "$1" ls -q --filter "label=com.docker.compose.project=$2" 2> /dev/null; }
# Prints what is still labelled with a project; empty when nothing is.
left_of() {
  docker ps -aq --filter "label=com.docker.compose.project=$1"
  labelled volume "$1"
  labelled network "$1"
  labelled image "$1"
}
listening() { (exec 3<> "/dev/tcp/127.0.0.1/$1") 2> /dev/null; }
# A CI log keeps no files: a failed start shows the end of its log.
up() {
  local start
  start="$(date +%s)"
  "$1/bin/up" > "$2" 2>&1 || { tail -n 30 "$2" >&2; fail "bin/up in $1"; }
  echo "TIME: bin/up $(basename "$1") $(($(date +%s) - start))s"
}
copy_checkout() {
  mkdir -p "$1"
  # Tracked and new files, not ignored ones such as .env or .env.session.
  (cd "$root" && git ls-files -co --exclude-standard -z \
    | while IFS= read -r -d '' file; do [ ! -e "$file" ] || printf '%s\0' "$file"; done \
    | tar --null -T - -cf -) | tar -xf - -C "$1"
}

copy_checkout "$a"
copy_checkout "$b"
# b's stack has one service that watches a path, synced into its container.
cat >> "$b/docker-compose.local.yml" <<'YAML'
  watched:
    image: busybox:1.37@sha256:a7dbc319b1438115a207e11930dc4bb3e643dcb3ec0bdd694bb36cd8fad289ec
    command: [sleep, infinity]
    init: true
    cpus: 0.1
    mem_limit: 32m
    logging:
      driver: json-file
      options:
        max-size: 8m
        max-file: "2"
    develop:
      watch:
        - action: sync
          path: ./tmp/watched
          target: /watched
YAML
mkdir -p "$b/tmp/watched"

# [dev-sessions-61e5a3] [dev-sessions-35b81e] Both start at once, without .env.
[ ! -e "$a/.env" ] && [ ! -e "$b/.env" ] || fail 'a copy has a .env'
up "$a" "$output/up-a.log" &
pid_a=$!
up "$b" "$output/up-b.log" &
pid_b=$!
wait "$pid_a" || fail 'the first bin/up in a failed'
wait "$pid_b" || fail 'the first bin/up in b failed'
grep -Eq '^POSTGRES_PASSWORD=[0-9a-f]{32}$' "$a/.env" || fail 'bin/up wrote no .env in a'
pass '[dev-sessions-35b81e] bin/up starts a checkout without .env'
slot_a="$(value "$a" FACTORY_SESSION_ID)"
slot_b="$(value "$b" FACTORY_SESSION_ID)"
project_a="$(value "$a" COMPOSE_PROJECT_NAME)"
project_b="$(value "$b" COMPOSE_PROJECT_NAME)"
port_a="$(value "$a" FACTORY_PORT_POSTGRES)"
port_b="$(value "$b" FACTORY_PORT_POSTGRES)"
[ "$slot_a" != "$slot_b" ] && [ "$port_a" != "$port_b" ] || fail 'worktrees share a slot or port'

# [dev-sessions-9bfe82]
user_a="$(sed -n 's/^POSTGRES_USER=//p' "$a/.env")"
grep -qx "  Postgres  postgres://$user_a@127.0.0.1:$port_a/app" "$output/up-a.log" || fail "URL not printed: $(cat "$output/up-a.log")"
api_a="$(value "$a" FACTORY_PORT_API)"
api_b="$(value "$b" FACTORY_PORT_API)"
ui_a="$(value "$a" FACTORY_PORT_UI)"
ui_b="$(value "$b" FACTORY_PORT_UI)"
grep -qx "  UI        http://127.0.0.1:$ui_a" "$output/up-a.log" || fail "UI URL not printed: $(cat "$output/up-a.log")"
grep -qx "  GraphQL   http://127.0.0.1:$api_a/graphql" "$output/up-a.log" || fail "GraphQL URL not printed: $(cat "$output/up-a.log")"
# Only bin/up's own lines: the image build's log may quote URLs.
[ "$(grep -cE '^  [A-Za-z]+ +[a-z]+://' "$output/up-a.log")" = 3 ] || fail "another URL is printed: $(cat "$output/up-a.log")"
! grep -qF "$(sed -n 's/^POSTGRES_PASSWORD=//p' "$a/.env")" "$output/up-a.log" || fail 'the password is printed'
unhealthy="$(docker ps --filter "label=com.docker.compose.project=$project_a" --format '{{.Status}}' | grep -vc '(healthy)' || true)"
[ "$unhealthy" = 0 ] || fail "$unhealthy containers of a are not healthy"
for port in "$port_a" "$port_b"; do listening "$port" || fail "Postgres does not listen on port $port"; done
pass '[dev-sessions-9bfe82] bin/up starts each stack healthy and prints its URLs'

# [service-checks-7707f9] [service-checks-b99553] Each stack's backend answers.
for port in "$api_a" "$api_b"; do
  [ "$(curl -fsS "http://127.0.0.1:$port/health")" = '{"ok":true}' ] || fail "/health on port $port"
done
pass '[service-checks-7707f9] GET /health answers {"ok":true} on every stack'
for port in "$api_a" "$api_b"; do
  [ "$(curl -fsS -H 'content-type: application/json' -d '{"query":"{ health { ok } }"}' "http://127.0.0.1:$port/graphql")" = '{"data":{"health":{"ok":true}}}' ] ||
    fail "the health query on port $port"
done
pass '[service-checks-b99553] the GraphQL health query answers true on every stack'

# [dev-sessions-b93c17] Each stack serves its UI.
for port in "$ui_a" "$ui_b"; do
  out="$(curl -fsS "http://127.0.0.1:$port/")" || fail "the UI on port $port"
  grep -q '<div id="root">' <<< "$out" || fail "the UI on port $port"
done
pass '[dev-sessions-b93c17] every stack serves the UI'

# cors <api port> <origin> [curl flags]: the response headers of a health query from origin.
cors() {
  local port="$1" origin="$2"
  shift 2
  curl -sS -o /dev/null -D - -H "origin: $origin" "$@" "http://127.0.0.1:$port/graphql" | tr -d '\r'
}
query=(-H 'content-type: application/json' -d '{"query":"{ health { ok } }"}')
out="$(cors "$api_a" "http://127.0.0.1:$ui_a" "${query[@]}")" || fail 'the health query'
grep -qix "access-control-allow-origin: http://127.0.0.1:$ui_a" <<< "$out" || fail "the API of a does not allow its UI"
out="$(cors "$api_b" "http://127.0.0.1:$ui_b" "${query[@]}")" || fail 'the health query'
grep -qix "access-control-allow-origin: http://127.0.0.1:$ui_b" <<< "$out" || fail "the API of b does not allow its UI"
pass "[service-checks-2900a9] each stack's API allows its own UI's origin"
for origin in http://elsewhere.test "http://127.0.0.1:$ui_b"; do
  out="$(cors "$api_a" "$origin" "${query[@]}")" || fail 'the health query'
  ! grep -qi '^access-control-allow-origin' <<< "$out" || fail "the API of a allows $origin"
done
pass "[service-checks-3e0690] another origin, another stack's UI included, gets no CORS header"
out="$(cors "$api_a" "http://127.0.0.1:$ui_a" -X OPTIONS -H 'access-control-request-method: POST' \
  -H 'access-control-request-headers: content-type')" || fail 'the preflight'
[[ "${out%%$'\n'*}" == *' 204'* ]] || fail 'the preflight did not answer 204'
pass '[service-checks-02099e] a preflight from the UI answers 204'

# [dev-sessions-61e5a3]
psql_in "$a" 'CREATE TABLE only_a (id int)' > /dev/null || fail 'create the table in a'
[ -z "$(psql_in "$b" "SELECT to_regclass('only_a')")" ] || fail 'the table of a is visible in b'
pass '[dev-sessions-61e5a3] two worktrees run isolated stacks'

# [dev-sessions-ae7e18] [dev-sessions-a29c95] bin/stop returns once nothing of a runs.
psql_in "$a" 'INSERT INTO only_a VALUES (42)' > /dev/null || fail 'insert a row in a'
"$a/bin/stop" > "$output/stop-a.log" 2>&1 || fail "bin/stop in a: $(cat "$output/stop-a.log")"
running="$(docker ps --filter "label=com.docker.compose.project=$project_a" --format '{{.Label "com.docker.compose.service"}} ({{.Status}})' | tr '\n' ' ')"
[ -z "$running" ] || fail "containers run after bin/stop: $running"
up "$a" "$output/up-a-again.log"
[ "$(value "$a" FACTORY_SESSION_ID)" = "$slot_a" ] || fail 'slot changed across bin/stop and bin/up'
[ "$(psql_in "$a" 'SELECT id FROM only_a')" = 42 ] || fail 'the row was lost across bin/stop and bin/up'
pass "[dev-sessions-ae7e18] [dev-sessions-a29c95] data survives bin/stop, which waits for the stack, and bin/up"

# [dev-sessions-fe78a8]
"$b/bin/up" --watch > "$output/up-b-watch.log" 2>&1 &
watch_pid=$!
for _ in $(seq 120); do grep -q 'Watch enabled' "$output/up-b-watch.log" && break; sleep 1; done
grep -q 'Watch enabled' "$output/up-b-watch.log" || fail "bin/up --watch did not watch: $(tail -n 20 "$output/up-b-watch.log")"
echo "changed $(date +%s)" > "$b/tmp/watched/x"
for _ in $(seq 60); do
  [ "$("$b/bin/compose" exec -T watched cat /watched/x 2> /dev/null)" = "$(cat "$b/tmp/watched/x")" ] && break
  sleep 1
done
[ "$("$b/bin/compose" exec -T watched cat /watched/x 2> /dev/null)" = "$(cat "$b/tmp/watched/x")" ] || fail 'the edit did not reach the container'
kill -0 "$watch_pid" 2> /dev/null || fail 'bin/up --watch did not stay attached'
kill "$watch_pid"
wait "$watch_pid" 2> /dev/null || true
watch_pid=""
pass '[dev-sessions-fe78a8] bin/up --watch stays attached and syncs an edit into the container'

# [dev-sessions-6834b6] [dev-sessions-e6c033]
# One watch is two processes: the docker CLI and its Compose plugin child,
# which is not counted. pgrep -f cannot match a path with spaces literally.
# shellcheck disable=SC2009
watches() { ps -axo args | grep -F -- "--project-directory $b " | grep -v cli-plugins | grep -c ' watch$' || true; }
"$root/bin/session" watch-start "$slot_b" "$b" > "$output/watch-start.log" 2>&1 || fail "watch-start: $(cat "$output/watch-start.log")"
"$root/bin/session" watch-start "$slot_b" "$b" >> "$output/watch-start.log" 2>&1 || fail "watch-start again: $(cat "$output/watch-start.log")"
[ "$(watches)" = 1 ] || fail "$(watches) watches of b run"
grep -q 'Watch enabled' "$HOME/.factory/orca-watch-$slot_b.log" || fail 'the watch log has no output'
pass '[dev-sessions-6834b6] [dev-sessions-e6c033] watch-start leaves exactly one logged watch running'

# [dev-sessions-822f79] [dev-sessions-34b617]
"$a/bin/down" > "$output/down-a.log" 2>&1 || fail 'bin/down in a'
[ -z "$(left_of "$project_a")" ] || fail "$project_a left: $(left_of "$project_a" | tr '\n' ' ')"
[ ! -e "$a/.env.session" ] || fail 'the session file of a is left'
! "$root/bin/session" slot-for "$a" > /dev/null || fail 'the slot of a is still held'
pass '[dev-sessions-34b617] bin/down leaves nothing behind'
[ -z "$(psql_in "$b" "SELECT to_regclass('only_a')")" ] || fail 'b changed'
[ "$(watches)" = 1 ] || fail 'the watch of b stopped'
pass '[dev-sessions-822f79] bin/down in one worktree leaves the other running'

# [dev-sessions-daaa07] [dev-sessions-27f723] [dev-sessions-afe93a]
rm -rf "$b"
copy_checkout "$c"
up "$c" "$output/up-c.log"
# Another bin/up on the host may reap it first; what counts is that it is gone.
# c may take b's freed slot, so b's project can be c's live stack again.
if [ "$(value "$c" COMPOSE_PROJECT_NAME)" = "$project_b" ]; then
  [ -z "$(docker ps -aq --filter "label=com.docker.compose.project.working_dir=$b")" ] ||
    fail "containers of the deleted worktree are left after the reap"
else
  [ -z "$(left_of "$project_b")" ] || fail "$project_b left after the reap: $(left_of "$project_b" | tr '\n' ' ')"
fi
[ "$(watches)" = 0 ] || fail 'the watch of the deleted worktree still runs'
pass '[dev-sessions-daaa07] bin/up reaps the stack and the watch of a deleted worktree'

"$c/bin/down" > "$output/down-c.log" 2>&1 || fail 'bin/down in c'
pass 'every stack is removed'
