# shellcheck shell=bash disable=SC2154
# bin/setup-env.sh: the local .env written from the committed .env.example.
# Fixtures copy bin/ and a made-up example into the temporary repository.

env_fixture() {
  cp -R "$ROOT/bin" .
  cat > .env.example <<'EXAMPLE'
# A made-up example.
A=1
B=x=y z # a value with = and spaces

SECRET= # generated
OTHER=
EXAMPLE
}

value() { sed -n "s/^$1=//p" "${2:-.env}"; }
is_hex32() { printf '%s' "$1" | grep -Eqx '[0-9a-f]{32}'; }

# [dev-sessions-bd285f]
test_only_the_example_is_committed() {
  git -C "$ROOT" ls-files --error-unmatch .env.example > /dev/null 2>&1 || fail ".env.example is not tracked"
  [ -z "$(git -C "$ROOT" ls-files .env)" ] || fail ".env is tracked"
  git -C "$ROOT" check-ignore -q .env || fail ".env is not ignored"
  local bad
  bad="$(grep -Evx '(#.*|[A-Z][A-Z0-9_]*=.*|)' "$ROOT/.env.example" || true)"
  [ -z "$bad" ] || fail "unexpected lines in .env.example: $bad"
}

# [dev-sessions-057e31]
test_fresh_checkout_gets_env() {
  env_fixture
  expect_pass bin/setup-env.sh
  expect_output 'Wrote .env'
  [ "$(value A)" = 1 ] || fail "A is '$(value A)'"
  [ "$(value B)" = 'x=y z' ] || fail "B is '$(value B)'"
  is_hex32 "$(value SECRET)" || fail "SECRET is '$(value SECRET)'"
  is_hex32 "$(value OTHER)" || fail "OTHER is '$(value OTHER)'"
  [ "$(value SECRET)" != "$(value OTHER)" ] || fail "two generated values are equal"
}

# [dev-sessions-e13300]
test_generated_values_differ_per_checkout() {
  env_fixture
  mkdir other
  cp -R bin .env.example other/
  expect_pass bin/setup-env.sh
  (cd other && git init -q && bin/setup-env.sh > /dev/null)
  [ "$(value SECRET)" != "$(value SECRET other/.env)" ] || fail "both checkouts generated the same value"
}

# [dev-sessions-01e6a1]
test_env_is_private() {
  env_fixture
  expect_pass bin/setup-env.sh
  # shellcheck disable=SC2012 # ls is the portable way to read a mode on BSD and GNU
  [ "$(ls -l .env | cut -c1-10)" = '-rw-------' ] || fail "mode is $(ls -l .env)"
}

# [dev-sessions-6bb305]
test_rerun_changes_nothing() {
  env_fixture
  expect_pass bin/setup-env.sh
  cp .env first
  expect_pass bin/setup-env.sh
  expect_output '.env is up to date'
  cmp -s first .env || fail ".env changed on the second run"
}

# [dev-sessions-0b0d6c]
test_new_variable_is_added_and_old_values_kept() {
  env_fixture
  expect_pass bin/setup-env.sh
  local secret
  secret="$(value SECRET)"
  # A .env edited by hand may lose its final newline.
  printf 'MINE=1' >> .env
  echo 'NEW= # generated' >> .env.example
  expect_pass bin/setup-env.sh
  expect_output 'Added to .env: NEW'
  [ "$(value SECRET)" = "$secret" ] || fail "SECRET was rotated"
  [ "$(value MINE)" = 1 ] || fail "MINE is '$(value MINE)'"
  is_hex32 "$(value NEW)" || fail "NEW is '$(value NEW)': $(cat .env)"
  # shellcheck disable=SC2012
  [ "$(ls -l .env | cut -c1-10)" = '-rw-------' ] || fail "mode is $(ls -l .env)"
}

# [dev-sessions-40df32]
test_setup_env_help_needs_nothing() {
  env_fixture
  PATH="/usr/bin:/bin" expect_pass bin/setup-env.sh --help
  expect_output 'Usage'
  [ ! -e .env ] || fail "--help wrote .env"
}
