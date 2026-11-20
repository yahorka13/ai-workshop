#!/usr/bin/env bash
# Docker-backed proof of bin/mutate on backend and ui; run by the mutation
# workflow, not by the fast script tests.
set -euo pipefail
if [ "$#" -eq 1 ] && [ "$1" = --help ]; then
  cat <<'HELP'
usage: bin/tests/mutate.e2e.sh

Requires Docker. Commits the probes in bin/tests/fixtures/mutate/ into a
temporary copy of the checkout as it is on disk and runs the real bin/mutate
there. In backend: a weakly tested probe fails a changed run with its survivor
and its uncovered function listed, thrown error texts and schema settings are
not mutated while a returned text and resolver code are, a strongly tested
probe passes, and a full run narrowed to the probe reports without failing.
In ui: class names are not mutated while the condition picking one and a
rendered text are. Five Stryker runs, each with its service's whole first
test run: allow about 20 minutes. Logs remain in tmp/mutate-proof/; the
checkout is unchanged. The mutation workflow runs it.
HELP
  exit 0
fi
[ "$#" -eq 0 ] || { echo 'Use --help for usage' >&2; exit 2; }
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
mkdir -p "$root/tmp/mutate-proof"
output="$(mktemp -d "$root/tmp/mutate-proof/run.$$.XXXXXX")"
work="$output/work"
fixtures="$root/bin/tests/fixtures/mutate"
cleanup() {
  local status=$?
  trap - EXIT INT TERM
  rm -rf "$work"
  echo "E2E artifacts: $output"
  exit "$status"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
fail() { echo "FAIL: $*; see $output" >&2; exit 1; }
pass() { echo "PASS: $*"; }

# A fresh repository holding the checkout as it is on disk, committed or not.
mkdir -p "$work"
(cd "$root" && git ls-files -z --cached --others --exclude-standard | COPYFILE_DISABLE=1 tar --null -T - -cf -) | tar -xf - -C "$work"
git -C "$work" init -q -b main
git -C "$work" add -A
git -C "$work" -c user.name=Proof -c user.email=proof@example.com commit -q -m "[10] Checkout"
start="$(git -C "$work" rev-parse HEAD)"
probe() {
  cp "$fixtures/$1/mutation-probe.ts" "$work/services/backend/src/mutation-probe.ts"
  cp "$fixtures/$1/mutation-probe.test.ts" "$work/services/backend/tests/unit/mutation-probe.test.ts"
  git -C "$work" add -A
  git -C "$work" -c user.name=Proof -c user.email=proof@example.com commit -q -m "[10] Probe: $1"
}
# Runs bin/mutate on $service (backend unless set) in the worktree; its output
# goes to $output/<log>.log, its exit code to $status.
mutate() {
  local log="$1"
  shift
  status=0
  "$work/bin/mutate" "${service:-backend}" "$@" > "$output/$log.log" 2>&1 || status=$?
  summary="$(sed -n 's/^Reports: //p' "$output/$log.log")/summary.md"
  [ -f "$summary" ] || fail "$log: no summary.md"
  cp "$summary" "$output/$log.summary.md"
}
has() { grep -qF -- "$2" "$output/$1.summary.md"; }
line_of() { grep -nF -- "$1" "$fixtures/weak/mutation-probe.ts" | cut -d: -f1; }

probe weak
mutate weak --changed --base "$start"
[ "$status" -eq 1 ] || fail "a weakly tested probe passed the changed run"
grep -q '^backend: failed$' "$output/weak.log" || fail 'no failed line'
has weak "| src/mutation-probe.ts:$(line_of 'age >= 18') | EqualityOperator | \`age >= 18\` → \`age > 18\` | Survived |" \
  || fail 'the survivor is not listed with its file, line, mutator and code'
pass '[service-checks-d0f5a5] a surviving mutant fails the changed run'
{ has weak "| src/mutation-probe.ts:$(line_of '41 + 1') |" && has weak '| NoCoverage |'; } \
  || fail 'the uncovered function is not listed as NoCoverage'
pass '[service-checks-a16f43] an uncovered mutant fails the changed run'
for text in '"ProbeError"' '"probe failed"'; do
  ! has weak "| src/mutation-probe.ts:$(line_of "$text") | StringLiteral |" || fail "$text was mutated"
done
pass '[service-checks-3695c6] thrown error texts are not mutated'
has weak "| src/mutation-probe.ts:$(line_of '"probe reason"') | StringLiteral |" || fail 'the returned text was not mutated'
pass '[service-checks-c589e9] a returned text is still mutated'
! has weak "| src/mutation-probe.ts:$(line_of '"probe description"') |" || fail 'a schema setting was mutated'
pass '[service-checks-60d662] a schema setting is not mutated'
has weak "| src/mutation-probe.ts:$(line_of 'status === "other"') |" || fail 'the resolver code was not mutated'
pass '[service-checks-509f55] resolver code is still mutated'

probe strong
mutate strong --changed --base "$start"
[ "$status" -eq 0 ] || fail "a strongly tested probe failed the changed run"
{ grep -q '^backend: passed$' "$output/strong.log" && has strong 'Mutation score: 100.00%'; } || fail 'no pass or score'
pass '[service-checks-e1c617] killed mutants pass the changed run'

# A change Stryker finds nothing to mutate in: a comment line only.
sed -i.bak 's|^export function reason|// What the client is told.\nexport function reason|' "$work/services/backend/src/mutation-probe.ts"
rm "$work/services/backend/src/mutation-probe.ts.bak"
git -C "$work" -c user.name=Proof -c user.email=proof@example.com commit -q -am "[10] Probe: comment only"
mutate comment --changed --base HEAD~1
[ "$status" -eq 0 ] || fail 'a change with no mutant failed the changed run'
has comment 'No mutants' || fail 'a change with no mutant does not say so'
pass 'a change with no mutant passes the changed run'
git -C "$work" reset -q --hard HEAD~1

git -C "$work" reset -q --hard HEAD~1
before="$(find "$work/tmp/mutate/backend" -mindepth 1 -maxdepth 1 | wc -l)"
MUTATE_FULL_GLOB=src/mutation-probe.ts mutate full
[ "$status" -eq 0 ] || fail 'the full run failed on survivors'
{ has full 'Mutation score:' && has full '| Survived |'; } || fail 'the full run does not report the score and survivors'
after="$(find "$work/tmp/mutate/backend" -mindepth 1 -maxdepth 1 | wc -l)"
[ "$after" -eq $((before + 1)) ] || fail 'no new reports folder'
for report in mutation.json mutation.html summary.md; do
  [ -f "$(sed -n 's/^Reports: //p' "$output/full.log")/$report" ] || fail "no $report"
done
pass '[service-checks-748bc5] [service-checks-b71438] a full run reports survivors without failing, in a new reports folder'

# ui: class names are styling, not behaviour.
git -C "$work" reset -q --hard "$start"
cp "$fixtures/ui/mutation-probe.tsx" "$work/services/ui/src/mutation-probe.tsx"
cp "$fixtures/ui/mutation-probe.test.tsx" "$work/services/ui/tests/unit/mutation-probe.test.tsx"
git -C "$work" add -A
git -C "$work" -c user.name=Proof -c user.email=proof@example.com commit -q -m "[10] Probe: ui"
service=ui mutate ui --changed --base "$start"
[ "$status" -eq 1 ] || fail 'the weakly tested ui probe passed the changed run'
ui_line() { grep -nF -- "$1" "$fixtures/ui/mutation-probe.tsx" | cut -d: -f1; }
for text in '"probe-box"' '"probe-a"' '"probe-b"'; do
  ! has ui "| src/mutation-probe.tsx:$(ui_line "$text") | StringLiteral |" || fail "class $text was mutated"
done
has ui "| src/mutation-probe.tsx:$(ui_line 'active && "probe-b"') |" || fail 'the condition picking a class was not mutated'
has ui "| src/mutation-probe.tsx:$(ui_line '{"probe text"}') | StringLiteral |" || fail 'the rendered text was not mutated'
pass '[service-checks-e5eec4] class names are not mutated, the condition and the rendered text are'
