#!/usr/bin/env bash
# Docker-backed proof of bin/contracts generate on a copy of the repository;
# not part of fast script tests. CI runs it in the contracts-proof job.
set -euo pipefail
if [ "$#" -eq 1 ] && [ "$1" = --help ]; then
  cat <<'HELP'
usage: bin/tests/contracts.e2e.sh

Requires Docker. Copies the files git tracks into a fresh repository under
tmp/contracts-proof/, runs bin/contracts generate there and proves:
  - the backend's contract is generated before the ui's typed documents;
  - every file of the ui's generated folder carries the generated notice;
  - the committed files are what generation produces: nothing changes.

No host Bun or Node, running stack, credentials or network for generation is
needed. Prints PASS lines; logs remain in tmp/contracts-proof/.
HELP
  exit 0
fi
[ "$#" -eq 0 ] || { echo 'Use --help for usage' >&2; exit 2; }
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
mkdir -p "$root/tmp/contracts-proof"
output="$(mktemp -d "$root/tmp/contracts-proof/run.$$.XXXXXX")"
copy="$output/repo"

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
git -C "$copy" init -q
git -C "$copy" add -A
git -C "$copy" -c user.name=proof -c user.email=proof@example.invalid commit -qm base --no-verify

"$copy/bin/contracts" generate > "$output/generate.log" 2>&1 || fail 'bin/contracts generate'
backend_line="$(grep -n '^backend: generate' "$output/generate.log" | cut -d: -f1 | head -n 1)"
ui_line="$(grep -n '^ui: generate' "$output/generate.log" | cut -d: -f1 | head -n 1)"
[ -n "$backend_line" ] && [ -n "$ui_line" ] || fail 'a service did not generate'
[ "$backend_line" -lt "$ui_line" ] || fail 'the ui generated before the backend'
for file in "$copy"/services/ui/src/services/graphql/generated/*; do
  [ "$(head -n 1 "$file")" = '// Generated file: do not edit it by hand.' ] || fail "no notice in ${file#"$copy"/}"
done
changes="$(git -C "$copy" status --porcelain)"
[ -z "$changes" ] || fail "generation changed committed files: $changes"
pass '[contracts-adbbb1] the backend generates first, then the ui; every ui file carries the notice and nothing changes'
