# shellcheck shell=bash disable=SC2154
# bin/setup: its steps in order, safe to run again. A restricted PATH with a
# stub claude stands in for the real tools; the stub records whether the git
# hooks were already enabled when it ran.

setup_fixture() {
  local tool
  cp -R "$ROOT/bin" "$ROOT/.githooks" "$ROOT/.claude" "$ROOT/.env.example" .
  mkdir -p "$REPO/tools"
  for tool in bash sh env cat grep sed awk tr cut find dirname mkdir cmp rm touch cp git od chmod tail; do
    ln -s "$(command -v "$tool")" "$REPO/tools/$tool"
  done
  cat > "$REPO/tools/claude" <<'STUB'
#!/bin/bash
echo "claude $* hooks=$(git config core.hooksPath) env=$(test -f "$REPO/.env" && echo yes)" >> "$REPO/claude.log"
case "$1 $2" in
  "plugin list") echo '[]' ;;
esac
STUB
  printf '#!/bin/bash\n' > "$REPO/tools/npx"
  chmod +x "$REPO/tools/claude" "$REPO/tools/npx"
  export REPO
  export PATH="$REPO/tools"
}

test_setup_runs_hooks_then_plugins() {
  setup_fixture
  expect_pass bin/setup
  expect_output 'Setup done.'
  grep -q '^claude plugin install superpowers@claude-plugins-official .* hooks=.githooks env=yes$' "$REPO/claude.log" \
    || fail "plugins were not installed after the hooks: $(cat "$REPO/claude.log")"
}

test_setup_is_idempotent() {
  setup_fixture
  expect_pass bin/setup
  expect_pass bin/setup
  [ "$(git config core.hooksPath)" = ".githooks" ] || fail "core.hooksPath is '$(git config core.hooksPath)'"
}

# [dev-sessions-cd162d]
test_setup_writes_env_between_hooks_and_plugins() {
  setup_fixture
  expect_pass bin/setup
  expect_output 'Wrote .env'
  [ -f .env ] || fail "no .env"
  grep -q ' hooks=.githooks env=yes$' "$REPO/claude.log" \
    || fail "the plugins step ran before .env was written: $(cat "$REPO/claude.log")"
}
