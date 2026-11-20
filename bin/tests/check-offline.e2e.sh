#!/usr/bin/env bash
# Docker-backed proof that bin/check runs the gates with no network; not part
# of fast script tests. CI runs it in the check-offline-proof job.
set -euo pipefail
if [ "$#" -eq 1 ] && [ "$1" = --help ]; then
  cat <<'HELP'
usage: bin/tests/check-offline.e2e.sh

Requires Docker. Copies the files git tracks into tmp/check-offline-proof/,
adds a backend unit test there that fetches a public URL, and proves that
bin/check backend --gates coverage fails, and names the coverage gate as
having tried to reach the network, after the line naming it failed. That every
gate passes offline without such a test is what CI's backend-checks and
ui-checks jobs prove on every run.

Building the checks image needs the network as usual; only the gates run
offline. Prints PASS lines; logs remain in tmp/check-offline-proof/.
HELP
  exit 0
fi
[ "$#" -eq 0 ] || { echo 'Use --help for usage' >&2; exit 2; }
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
mkdir -p "$root/tmp/check-offline-proof"
output="$(mktemp -d "$root/tmp/check-offline-proof/run.$$.XXXXXX")"
copy="$output/repo"
probe="$copy/services/backend/tests/unit/network-probe.test.ts"
hint='backend: coverage tried to reach the network; checks run with no network on purpose: fake the provider at its contract'

cleanup() {
  local status=$?
  trap - EXIT INT TERM
  rm -rf "$copy"
  echo "E2E artifacts: $output"
  exit "$status"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
fail() { echo "FAIL: $*; see $output" >&2; exit 1; }
pass() { echo "PASS: $*"; }

mkdir -p "$copy"
(cd "$root" && git ls-files -z | xargs -0 tar -cf -) | (cd "$copy" && tar -xf -)

cat > "$probe" <<'TEST'
import { expect, test } from "bun:test";

test("a real provider answers", async () => {
  const response = await fetch("https://example.com");
  expect(response.status).toBe(200);
});
TEST
if "$copy/bin/check" backend --gates coverage > "$output/online.log" 2>&1; then
  fail 'a test that fetches a public URL passed'
fi
failed_line="$(grep -n '^backend: coverage failed; see ' "$output/online.log" | cut -d: -f1 | head -n 1)"
hint_line="$(grep -nxF "$hint" "$output/online.log" | cut -d: -f1 | head -n 1)"
[ -n "$failed_line" ] || fail 'the coverage gate was not named as failed'
[ -n "$hint_line" ] || fail 'no line says the coverage gate tried to reach the network'
[ "$failed_line" -lt "$hint_line" ] || fail 'the network line came before the failed line'
pass '[service-checks-5ed7ca] a test that fetches a public URL fails the coverage gate, which is named as having tried to reach the network'
