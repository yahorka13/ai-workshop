#!/usr/bin/env bash
# Docker-backed proof of the backend-owned migration history against the
# PostgreSQL image the stack runs; not part of fast script tests. CI runs it in
# the db-migrate-proof job.
set -euo pipefail
if [ "$#" -eq 1 ] && [ "$1" = --help ]; then
  cat <<'HELP'
usage: bin/tests/db-migrate.e2e.sh

Requires Docker. Builds the backend's runtime image three times: with its own
history, with the two-migration fixture history and with the broken fixture
history (a valid migration, then a failing one). Against postgres:17-alpine
on a private network it proves:
  - --help prints usage with no database configured;
  - the first run applies and records both migrations, in folder order;
  - a second run applies nothing and exits 0;
  - two runners started together both exit 0 and record each migration once;
  - the broken history records nothing and exits nonzero quoting the failed
    statement;
  - the image's own command applies the history before /health first answers;
  - against an unreachable database the image exits nonzero and never serves.

No host Bun or Node and no credentials needed: the database password is
generated per run and never printed. Prints PASS lines; logs remain in
tmp/db-proof/.
HELP
  exit 0
fi
[ "$#" -eq 0 ] || { echo 'Use --help for usage' >&2; exit 2; }
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
mkdir -p "$root/tmp/db-proof"
output="$(mktemp -d "$root/tmp/db-proof/run.$$.XXXXXX")"
id="$(printf '%s' "${output##*.}" | tr '[:upper:]' '[:lower:]')"
name="factory-db-proof-$id"
network="$name"
pg="$name-pg"
backend="$name-backend"
postgres_image=postgres:17.12-alpine@sha256:a77aa70e641402a21411b92b721c58d10f23b50ae5fdd2333efd22d166e1e5f7 # the stack's database image
# No `head` in the middle of a pipeline: it would SIGPIPE its writer under pipefail.
password="$(head -c 24 /dev/urandom | base64 | LC_ALL=C tr -dc 'a-zA-Z0-9')"
password="${password:0:24}"
auth_secret="$password$password" # 48 characters; the backend needs 32

cleanup() {
  local status=$?
  trap - EXIT INT TERM
  docker rm -f "$pg" "$backend" > /dev/null 2>&1 || true
  docker network rm "$network" > /dev/null 2>&1 || true
  docker image rm "$name:own" "$name:ordered" "$name:broken" > /dev/null 2>&1 || true
  rm -rf "$output/context"
  echo "E2E artifacts: $output"
  exit "$status"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
fail() { echo "FAIL: $*; see $output" >&2; exit 1; }
pass() { echo "PASS: $*"; }

# Local socket connections in the postgres image are trusted, so assertions
# need no password.
sql() { docker exec "$pg" psql -U app -d "${2:-app}" -tAXc "$1"; }
recorded() { sql 'select count(*) from drizzle.__drizzle_migrations' "${1:-app}"; }
# run <image> <database> <command...>: one container on the private network.
run() {
  local image="$1" database="$2"
  shift 2
  docker run --rm --network "$network" \
    -e POSTGRES_URL="postgres://$pg:5432" -e POSTGRES_USER=app -e POSTGRES_DB="$database" \
    -e POSTGRES_PASSWORD="$password" "$name:$image" "$@"
}

# build <tag> [<fixture>]: the runtime image, its history replaced by a fixture's.
build() {
  local context="$output/context/$1"
  mkdir -p "$context"
  (cd "$root/services/backend" && tar -cf - --exclude node_modules --exclude coverage .) | (cd "$context" && tar -xf -)
  if [ -n "${2:-}" ]; then
    rm -rf "$context/src/db/migrations"
    cp -R "$context/tests/fixtures/$2" "$context/src/db/migrations"
  fi
  docker build -t "$name:$1" "$context" > "$output/build-$1.log" 2>&1 || fail "building the $1 image"
}
build own
build ordered ordered-migrations
build broken broken-migrations

docker run --rm "$name:own" bun run db:migrate --help > "$output/help.log" 2>&1 || fail 'help exit status'
grep -q 'usage: bun run db:migrate' "$output/help.log" || fail 'help usage line'
pass '[database-cd5777] --help prints usage with no database configured'

docker network create "$network" > /dev/null
docker run -d --name "$pg" --network "$network" \
  -e POSTGRES_USER=app -e POSTGRES_DB=app -e POSTGRES_PASSWORD="$password" "$postgres_image" > /dev/null
# Over TCP: on first start the image runs a socket-only server to initialise
# the database, then restarts it, so a socket check can pass too early.
ready=
for _ in $(seq 1 60); do
  if docker exec "$pg" pg_isready -h 127.0.0.1 -U app -d app > /dev/null 2>&1; then ready=1; break; fi
  sleep 1
done
[ -n "$ready" ] || fail 'postgres never became ready'

run ordered app bun run db:migrate > "$output/first.log" 2>&1 || fail 'first apply'
[ "$(recorded)" = 2 ] || fail 'the first run did not record both migrations'
[ "$(sql "select count(*) from information_schema.columns where table_name = 'ordered' and column_name = 'second'")" = 1 ] ||
  fail 'the second migration did not run after the first'
pass "[database-14fedb] the first run applied both migrations to $postgres_image in folder order and recorded them"

run ordered app bun run db:migrate > "$output/second.log" 2>&1 || fail 'second apply'
[ "$(recorded)" = 2 ] || fail 'the second run recorded more'
pass '[database-f98489] a second run applies nothing and exits 0'

# Two runners inside one container, so they genuinely overlap: container
# startup alone staggers them enough to hide a race. Without the advisory lock
# one of them fails; with it, the loser waits and then finds the history
# current.
sql 'create database concurrent' > /dev/null
# shellcheck disable=SC2016 # expanded by the container's shell
run ordered concurrent sh -c '
  bun tooling/migrate.ts & first=$!
  bun tooling/migrate.ts & second=$!
  wait $first; one=$?
  wait $second; two=$?
  echo "exit codes: $one $two"
  exit $(( one + two ))
' > "$output/concurrent.log" 2>&1 || fail 'a concurrent runner failed'
[ "$(recorded concurrent)" = 2 ] || fail 'concurrent runs did not record each migration once'
pass '[database-76d7a6] two runners at once both exit 0 and record each migration once'

sql 'create database broken' > /dev/null
if run broken broken bun run db:migrate > "$output/broken.log" 2>&1; then fail 'the broken history exited 0'; fi
grep -q nosuchtype "$output/broken.log" || fail 'the error does not quote the failed statement'
[ "$(sql "select count(*) from information_schema.tables where table_name in ('kept', 'broken')" broken)" = 0 ] ||
  fail 'the failed run left a table behind'
[ "$(sql "select count(*) from information_schema.tables where table_schema = 'drizzle' and table_name = '__drizzle_migrations'" broken)" = 0 ] ||
  [ "$(recorded broken)" = 0 ] || fail 'the failed run recorded a migration'
pass '[database-129a02] a failing migration records nothing and exits nonzero quoting the statement'

# The image's own command against an empty database: the history is recorded
# by the time /health first answers.
sql 'create database served' > /dev/null
docker run -d --name "$backend" --network "$network" \
  -e POSTGRES_URL="postgres://$pg:5432" -e POSTGRES_USER=app -e POSTGRES_DB=served \
  -e POSTGRES_PASSWORD="$password" -e APP_URL=http://127.0.0.1:3000 \
  -e API_URL=http://127.0.0.1:4000 -e AUTH_SECRET="$auth_secret" "$name:ordered" > /dev/null
health=
for _ in $(seq 1 60); do
  # shellcheck disable=SC2016 # JavaScript, not shell
  health="$(docker exec "$backend" bun -e 'const r = await fetch("http://127.0.0.1:4000/health").catch(() => null); console.log(r ? `${r.status} ${await r.text()}` : "")' 2> /dev/null || true)"
  [ -n "$health" ] && break
  sleep 1
done
[ "$health" = '200 {"ok":true}' ] || fail "/health answered \"$health\""
[ "$(recorded served)" = 2 ] || fail 'the history was not recorded before /health answered'
docker logs "$backend" > "$output/served.log" 2>&1
pass '[database-8919a7] the image applied the history before /health first answered'

# Nothing listens on port 1: the migration fails, so the server never starts.
if docker run --rm -e POSTGRES_URL=postgres://127.0.0.1:1 -e POSTGRES_USER=app -e POSTGRES_DB=app \
  -e POSTGRES_PASSWORD="$password" -e APP_URL=http://127.0.0.1:3000 \
  -e API_URL=http://127.0.0.1:4000 -e AUTH_SECRET="$auth_secret" "$name:own" > "$output/unreachable.log" 2>&1; then
  fail 'the image exited 0 with no database'
fi
! grep -q 'backend listening' "$output/unreachable.log" || fail 'the server started with no database'
pass '[database-bb83e6] with no database the image exits nonzero and never serves'

! grep -rqF "$password" "$output" || fail 'a log recorded the database password'
pass 'no log records the database password'
