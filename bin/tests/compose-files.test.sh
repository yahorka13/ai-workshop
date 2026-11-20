# shellcheck shell=bash disable=SC2154
# The Compose files, rendered by the real `docker compose config`: the base
# topology, ports only in the session file, limits and shared settings. Docker
# Compose renders without a running daemon; without the docker CLI at all each
# test says SKIP and passes, so the rest of the suite still runs (CI has it).

compose_fixture() {
  if ! docker compose version > /dev/null 2>&1; then
    echo "SKIP: no docker compose"
    return 1
  fi
  cp "$ROOT"/docker-compose.yml "$ROOT"/docker-compose.local.yml "$ROOT"/docker-compose.session.yml .
  printf 'POSTGRES_USER=tester\nPOSTGRES_DB=testdb\nPOSTGRES_PASSWORD=synthetic-password\nAUTH_SECRET=synthetic-auth-secret\n' > .env
  printf 'COMPOSE_PROJECT_NAME=factory-2\nFACTORY_PORT_UI=11100\nFACTORY_PORT_API=11101\nFACTORY_PORT_POSTGRES=11102\nFACTORY_BIND_HOST=127.0.0.1\nFACTORY_PUBLIC_HOST=127.0.0.1\n' > .env.session
  unset COMPOSE_PROJECT_NAME
}

# config <file>...: the rendered configuration of those files with .env only.
config() {
  local args=() file
  for file in "$@"; do args+=(-f "$file"); done
  docker compose --project-directory "$REPO" --env-file .env "${args[@]}" config
}

config_session() {
  docker compose --project-directory "$REPO" --env-file .env --env-file .env.session \
    -f docker-compose.yml -f docker-compose.local.yml -f docker-compose.session.yml config
}

# [dev-sessions-2e17aa]
test_postgres_takes_its_credentials_from_the_environment() {
  compose_fixture || return 0
  OUT="$(config docker-compose.yml)"
  expect_output 'name: factory'
  expect_output 'image: postgres:17'
  expect_output 'POSTGRES_USER: tester'
  expect_output 'POSTGRES_DB: testdb'
  expect_output 'POSTGRES_PASSWORD: synthetic-password'
  expect_output 'healthcheck:'
  expect_output 'target: /var/lib/postgresql/data'
  printf '%s\n' "$OUT" | grep -A2 'type: volume' | grep -q 'source: postgres-data' || fail "no named data volume: $OUT"
}

# [dev-sessions-f200dc]
test_no_ports_without_the_session_file() {
  compose_fixture || return 0
  OUT="$(config docker-compose.yml docker-compose.local.yml)"
  if printf '%s\n' "$OUT" | grep -q 'published:'; then fail "a port is published: $OUT"; fi
  OUT="$(config_session)"
  expect_output 'published: "11102"'
  expect_output 'host_ip: 127.0.0.1'
  expect_output 'name: factory-2'
}

# [dev-sessions-069f42]
test_every_local_service_is_limited() {
  compose_fixture || return 0
  local services service json
  json="$(docker compose --project-directory "$REPO" --env-file .env --env-file .env.session \
    -f docker-compose.yml -f docker-compose.local.yml -f docker-compose.session.yml config --format json)"
  services="$(docker compose --project-directory "$REPO" --env-file .env -f docker-compose.yml config --services)"
  [ -n "$services" ] || fail "no services"
  for service in $services; do
    OUT="$(printf '%s' "$json" | tr -d '\n ' | grep -o "\"$service\":{.*" | head -c 4000)"
    printf '%s' "$OUT" | grep -Eq '"cpus":(0?\.[0-9]+|1(\.[0-9]+)?|2(\.0+)?)[,}]' || fail "$service has no CPU limit of at most 2"
    printf '%s' "$OUT" | grep -q '"mem_limit":"[0-9]' || fail "$service has no memory limit"
  done
}

# [dev-sessions-8e0ae4]
test_logs_are_bounded_and_health_checks_share_their_timing() {
  compose_fixture || return 0
  # Only the services: Compose also renders the x- blocks they share.
  OUT="$(config_session | awk '/^[a-z]/ { keep = ($0 == "services:") } keep')"
  local services healthchecks setting
  services="$(printf '%s\n' "$OUT" | grep -c '^    logging:' || true)"
  [ "$services" -ge 1 ] || fail "no logging block: $OUT"
  [ "$(printf '%s\n' "$OUT" | grep -c 'max-size: 8m')" = "$services" ] || fail "a service lacks max-size 8m"
  [ "$(printf '%s\n' "$OUT" | grep -c 'max-file: "2"')" = "$services" ] || fail "a service lacks max-file 2"
  healthchecks="$(printf '%s\n' "$OUT" | grep -c '^      healthcheck:\|^    healthcheck:' || true)"
  [ "$healthchecks" -ge 1 ] || fail "no health check"
  for setting in 'interval: 5s' 'start_period: 5s' 'timeout: 2s' 'retries: 3'; do
    [ "$(printf '%s\n' "$OUT" | grep -c "$setting")" -ge "$healthchecks" ] || fail "a health check lacks $setting"
  done
}

# [dev-sessions-3ee331]
test_dev_sessions_3ee331_the_backend_runs_in_the_stack() {
  compose_fixture || return 0
  OUT="$(config docker-compose.yml | awk '/^  backend:$/ { on = 1; print; next } on && /^  [a-z]/ { exit } on')"
  [ -n "$OUT" ] || fail "no backend service"
  # Compose resolves the project directory with or without symbolic links.
  printf '%s\n' "$OUT" | grep -qE '^      context: .*/services/backend$' || fail "backend is not built from services/backend: $OUT"
  expect_output 'target: runtime'
  expect_output 'POSTGRES_URL: postgres://postgres:5432'
  expect_output 'POSTGRES_USER: tester'
  expect_output 'POSTGRES_DB: testdb'
  expect_output 'POSTGRES_PASSWORD: synthetic-password'
  expect_output 'AUTH_SECRET: synthetic-auth-secret'
  printf '%s\n' "$OUT" | grep -A2 '^      postgres:$' | grep -q 'condition: service_healthy' || fail "backend does not wait for a healthy postgres: $OUT"
  printf '%s\n' "$OUT" | grep -A8 '^    healthcheck:$' | grep -q '/health' || fail "the backend's health check does not request /health: $OUT"
  expect_output 'max-size: 8m'
  expect_output 'private: null'
  if printf '%s\n' "$OUT" | grep -q '^    ports:'; then fail "the base file publishes a backend port: $OUT"; fi
  if printf '%s\n' "$OUT" | grep -q 'FACTORY_LOCAL_STACK'; then fail "the base file marks a local stack: $OUT"; fi
  OUT="$(config_session)"
  expect_output 'published: "11101"'
  expect_output 'API_URL: http://127.0.0.1:11101'
  expect_output 'FACTORY_LOCAL_STACK: "1"'
}

# [dev-sessions-a965a8]
test_dev_sessions_a965a8_the_backend_rebuilds_on_source_changes() {
  compose_fixture || return 0
  OUT="$(config_session | awk '/^  backend:$/ { on = 1; print; next } on && /^  [a-z]/ { exit } on')"
  local path
  for path in src package.json bun.lock; do
    printf '%s\n' "$OUT" | grep -B1 -A1 -E "path: .*/services/backend/$path\$" | grep -q 'action: rebuild' ||
      fail "no rebuild watch on services/backend/$path: $OUT"
  done
}

# [dev-sessions-b93c17]
test_dev_sessions_b93c17_the_ui_runs_in_the_stack() {
  compose_fixture || return 0
  OUT="$(config docker-compose.yml | awk '/^  ui:$/ { on = 1; print; next } on && /^  [a-z]/ { exit } on')"
  [ -n "$OUT" ] || fail "no ui service"
  printf '%s\n' "$OUT" | grep -qE '^      context: .*/services/ui$' || fail "ui is not built from services/ui: $OUT"
  expect_output 'target: runtime'
  printf '%s\n' "$OUT" | grep -A8 '^    healthcheck:$' | grep -q 'http://127.0.0.1:3000/' || fail "the ui's health check does not request its entry page: $OUT"
  printf '%s\n' "$OUT" | grep -A8 '^    healthcheck:$' | grep -q 'wget' || fail "the ui's health check does not use wget: $OUT"
  expect_output 'interval: 5s'
  expect_output 'max-size: 8m'
  expect_output 'private: null'
  if printf '%s\n' "$OUT" | grep -q '^    ports:'; then fail "the base file publishes a ui port: $OUT"; fi
  OUT="$(config_session | awk '/^  ui:$/ { on = 1; print; next } on && /^  [a-z]/ { exit } on')"
  expect_output 'target: 3000'
  expect_output 'published: "11100"'
}

# [dev-sessions-9fb5b8]
test_dev_sessions_9fb5b8_the_ui_rebuilds_on_source_changes() {
  compose_fixture || return 0
  OUT="$(config_session | awk '/^  ui:$/ { on = 1; print; next } on && /^  [a-z]/ { exit } on')"
  local ignored
  printf '%s\n' "$OUT" | grep -B1 -A1 -E 'path: .*/services/ui$' | grep -q 'action: rebuild' ||
    fail "no rebuild watch on services/ui: $OUT"
  for ignored in node_modules/ coverage/ dist/ tests/ AGENTS.md; do
    printf '%s\n' "$OUT" | grep -qE "^ +- $ignored\$" || fail "the ui's watch does not ignore $ignored: $OUT"
  done
}

# [dev-sessions-5dd1ec]
test_dev_sessions_5dd1ec_the_ui_calls_its_slots_api() {
  compose_fixture || return 0
  OUT="$(config_session)"
  printf '%s\n' "$OUT" | awk '/^  ui:$/ { on = 1; print; next } on && /^  [a-z]/ { exit } on' |
    grep -q 'VITE_API_URL: http://127.0.0.1:11101' || fail "the ui is not built against its slot's API: $OUT"
  printf '%s\n' "$OUT" | awk '/^  backend:$/ { on = 1; print; next } on && /^  [a-z]/ { exit } on' |
    grep -q 'APP_URL: http://127.0.0.1:11100' || fail "the backend does not allow its slot's UI: $OUT"
  sed -i.bak 's/^FACTORY_PUBLIC_HOST=.*/FACTORY_PUBLIC_HOST=box.test/' .env.session
  OUT="$(config_session)"
  expect_output 'VITE_API_URL: http://box.test:11101'
  expect_output 'APP_URL: http://box.test:11100'
}

# compose_copy: bin/compose and the cache layer beside the compose files.
compose_copy() {
  mkdir -p bin
  cp "$ROOT/bin/compose" bin/
  [ ! -f "$ROOT/docker-compose.cache.yml" ] || cp "$ROOT/docker-compose.cache.yml" .
}

# [dev-sessions-f7badf]
test_dev_sessions_f7badf_the_cache_layer_is_added_only_on_request() {
  compose_fixture || return 0
  compose_copy
  local rendered service
  rendered="$(FACTORY_BUILD_CACHE=gha bin/compose config)"
  for service in backend ui; do
    printf '%s\n' "$rendered" | sed -n "/^  $service:\$/,/^  [a-z]*:\$/p" | grep -qF "type=gha,scope=$service" \
      || fail "$service has no gha cache_from: $rendered"
    printf '%s\n' "$rendered" | sed -n "/^  $service:\$/,/^  [a-z]*:\$/p" | grep -qF "type=gha,mode=max,scope=$service" \
      || fail "$service has no gha cache_to: $rendered"
  done
  rendered="$(bin/compose config)"
  [[ "$rendered" != *cache_from* && "$rendered" != *cache_to* ]] || fail "a cache without the setting: $rendered"
}

# [dev-sessions-a3e5cb]
test_dev_sessions_a3e5cb_a_typo_in_the_cache_setting_fails() {
  compose_copy
  touch .env .env.session
  expect_fail env FACTORY_BUILD_CACHE=gh bin/compose ps
  expect_output 'FACTORY_BUILD_CACHE'
  expect_output 'gha'
}

test_compose_help_names_the_cache_setting() {
  compose_copy
  expect_pass bin/compose --help
  expect_output 'FACTORY_BUILD_CACHE'
  expect_output 'docker-compose.cache.yml'
}
