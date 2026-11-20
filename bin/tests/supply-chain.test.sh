# shellcheck shell=bash disable=SC2154
# bin/ci-secret-scan.sh and bin/audit: CI's supply-chain job. A fake docker
# logs every call, one argument per line after a "--" separator, and fails
# when DOCKER_FAIL_ON is one of its arguments' substrings.

supply_fixture() {
  STUBS="$REPO/stubs"
  mkdir -p "$STUBS"
  cat > "$STUBS/docker" <<'STUB'
#!/bin/bash
log="$(dirname "$0")/docker.log"
echo -- >> "$log"
printf '%s\n' "$@" >> "$log"
if [ -n "${DOCKER_FAIL_ON:-}" ]; then
  for arg in "$@"; do
    case "$arg" in *"$DOCKER_FAIL_ON"*) echo "finding in $arg"; exit 1 ;; esac
  done
fi
exit 0
STUB
  chmod +x "$STUBS/docker"
  export PATH="$STUBS:$PATH"
  unset DOCKER_FAIL_ON
}

calls() { cat "$STUBS/docker.log" 2> /dev/null; }

# [ci-41bb45]
test_secret_scan_fails_on_a_finding() {
  supply_fixture
  export DOCKER_FAIL_ON=--redact
  expect_fail "$BIN/ci-secret-scan.sh" HEAD HEAD
  expect_output 'remove the secret'
  expect_output 'rotate'
  expect_output 'gitleaks:allow'
  calls | grep -qx -- '--redact' || fail "not redacted: $(calls)"
  calls | grep -qx -- '--verbose' || fail "findings not printed: $(calls)"
  calls | grep -q ':/repo:ro$' || fail "checkout not mounted read-only: $(calls)"
}

# [ci-ae9a14]
test_secret_scan_passes_a_clean_range() {
  local head
  supply_fixture
  head="$(git rev-parse HEAD)"
  expect_pass "$BIN/ci-secret-scan.sh" "$head" "$head"
  calls | grep -qx -- "--log-opts=$head..$head" || fail "range not scanned: $(calls)"
  calls | grep -qx -- "$(cd .git && pwd -P):$(cd .git && pwd -P):ro" || fail "git directory not mounted: $(calls)"
}

# [ci-9e7f46]
test_secret_scan_without_a_base_scans_everything() {
  local base
  supply_fixture
  for base in '' 0000000000000000000000000000000000000000; do
    rm -f "$STUBS/docker.log"
    expect_pass "$BIN/ci-secret-scan.sh" "$base" HEAD
    calls | grep -qx -- '--log-opts=HEAD' || fail "base '$base' did not scan up to head: $(calls)"
  done
}

test_secret_scan_usage() {
  supply_fixture
  expect_pass "$BIN/ci-secret-scan.sh" --help
  expect_output 'usage: bin/ci-secret-scan.sh'
  expect_fail "$BIN/ci-secret-scan.sh"
  [ ! -e "$STUBS/docker.log" ] || fail 'docker called on bad usage'
}

# services/a and services/b have a lockfile, services/c has none.
services_fixture() {
  supply_fixture
  mkdir -p services/a services/b services/c
  touch services/a/bun.lock services/b/bun.lock
}

# [ci-f9b512]
test_audit_fails_and_keeps_going() {
  services_fixture
  export DOCKER_FAIL_ON=/services/a:
  expect_fail "$BIN/audit"
  expect_output '== a'
  expect_output '== b'
  expect_output 'audit failed for a'
  expect_output 'bun audit fix'
  calls | grep -q '/services/b:/src:ro$' || fail "b not audited after a failed: $(calls)"
}

# [ci-37c8df]
test_audit_passes_clean_services() {
  services_fixture
  expect_pass "$BIN/audit"
  calls | grep -q -- '--audit-level=high ' || fail "high advisories not reported: $(calls)"
  calls | grep -q -- '--audit-level=critical ' || fail "verdict not on critical: $(calls)"
  ! calls | grep -q '/services/c:' || fail "c has no lockfile but was audited: $(calls)"
  [[ "$OUT" != *'== c'* ]] || fail "c listed: $OUT"
}

test_audit_named_service_and_unknown() {
  services_fixture
  expect_pass "$BIN/audit" b
  ! calls | grep -q '/services/a:' || fail "a audited when only b was named: $(calls)"
  expect_fail "$BIN/audit" nope
  expect_output 'usage: bin/audit'
  expect_pass "$BIN/audit" --help
}
