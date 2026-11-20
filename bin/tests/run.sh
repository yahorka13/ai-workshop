#!/usr/bin/env bash
# Dependency-free test runner for the repository scripts: bash, git and
# coreutils only, so it runs the same on a laptop, in CI or in a container.
#
#     bin/tests/run.sh            # every bin/tests/*.test.sh
#     bin/tests/run.sh hooks      # only bin/tests/hooks.test.sh
#
# Every test_* function runs in its own subshell with `set -e`, inside a fresh
# temporary git repository. $ROOT is this repository and $BIN its bin/.
set -uo pipefail

TESTS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="$(cd "$TESTS/.." && pwd)"
# shellcheck disable=SC2034 # used by the sourced *.test.sh files
ROOT="$(cd "$BIN/.." && pwd)"

# Keep the developer's git config, editor and any enclosing hook's repository
# out of the tests.
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 GIT_EDITOR=true
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE

fail() {
  echo "  $*"
  exit 1
}

# expect_pass/expect_fail run a command and keep its combined output in $OUT.
expect_pass() {
  OUT="$("$@" 2>&1)" || fail "expected success: $*"$'\n'"$OUT"
}

expect_fail() {
  if OUT="$("$@" 2>&1)"; then
    fail "expected failure: $*"$'\n'"$OUT"
  fi
}

expect_output() {
  [[ "$OUT" == *"$1"* ]] || fail "expected output to contain: $1"$'\n'"$OUT"
}

new_repo() {
  REPO="$(mktemp -d)"
  cd "$REPO"
  git init -q -b main
  git config user.name Test
  git config user.email test@example.com
  git commit -q --allow-empty -m "[1] Initial"
}

# Printed after a test returns. bash 3.2 (macOS) reports status 0 for a subshell
# that aborted on an unbound variable once an EXIT trap has run, so the status
# alone cannot tell a finished test from an aborted one.
FINISHED="==test-finished=="

run_test() {
  (
    set -e
    REPO=""
    trap '[ -z "$REPO" ] || rm -rf "$REPO"' EXIT
    new_repo
    "$1"
    echo "$FINISHED"
  )
}

only="${1:-}"
passed=0
failed=0
for file in "$TESTS"/*.test.sh; do
  name="$(basename "$file" .test.sh)"
  [ -z "$only" ] || [ "$name" = "$only" ] || continue
  # shellcheck source=/dev/null
  source "$file"
  for test in $(declare -F | awk '$3 ~ /^test_/ { print $3 }'); do
    # A plain assignment, not an `if`: inside an `if` condition bash ignores
    # the `set -e` the test relies on.
    output="$(run_test "$test" 2>&1)"
    status=$?
    if [ "$status" -eq 0 ] && [[ "$output" == *"$FINISHED" ]]; then
      echo "ok   $name: $test"
      passed=$((passed + 1))
    else
      echo "FAIL $name: $test"
      echo "${output%"$FINISHED"}"
      failed=$((failed + 1))
    fi
    unset -f "$test"
  done
done

echo
echo "$passed passed, $failed failed"
[ "$failed" -eq 0 ] && [ "$passed" -gt 0 ]
