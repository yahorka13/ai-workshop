#!/usr/bin/env bash
# Run the end-to-end suite against a throwaway stack, then remove the stack.
# CI's `e2e` check.
set -euo pipefail
if [ "$#" -eq 1 ] && [ "$1" = --help ]; then
  cat <<'HELP'
usage: bin/tests/e2e-stack.e2e.sh

Requires Docker, git and one free session slot. Copies this checkout's working
tree into a temporary worktree, starts its stack with bin/up, runs bin/e2e
against it, checks every container ran healthy within its memory limit, and
always removes the stack with bin/down, checking nothing of it is left. Logs
and Playwright's report and traces remain in tmp/e2e-stack/; CI uploads them
when the suite fails. A failed start or suite also prints each container's
state and the last 200 lines of the backend's log, and keeps every service's
timestamped log in logs/. Each of bin/up, bin/e2e and bin/down prints a TIME:
line with its seconds.
HELP
  exit 0
fi
[ "$#" -eq 0 ] || { echo 'Use --help for usage' >&2; exit 2; }
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
mkdir -p "$root/tmp/e2e-stack"
output="$(mktemp -d "$root/tmp/e2e-stack/run.XXXXXX")"
copy="$output/worktree"

# The copy claims its own slot and host, whatever this shell was given.
unset FACTORY_PUBLIC_HOST FACTORY_BIND_HOST COMPOSE_PROJECT_NAME

# shellcheck source=bin/tests/stack-report.sh
. "$root/bin/tests/stack-report.sh"
# shellcheck source=bin/tests/proof-steps.sh
. "$root/bin/tests/proof-steps.sh"

fail() { echo "FAIL: $*; see $output" >&2; exit 1; }
pass() { echo "PASS: $*"; }
project=""

# [ci-eb41cf] The stack goes whether the suite passed or not.
cleanup() {
  local status=$? kind left=""
  trap - EXIT INT TERM
  if [ -d "$copy/tmp/e2e" ]; then cp -R "$copy/tmp/e2e" "$output/report" 2> /dev/null || true; fi
  # A failed run shows its stack and keeps its logs.
  if [ "$status" != 0 ] && [ -x "$copy/bin/compose" ]; then
    stack_report "$copy/bin/compose" "$output" >&2 || true
  fi
  if [ -x "$copy/bin/down" ]; then timed bin/down logged "$output/down.log" "$copy/bin/down" || status=1; fi
  if [ -n "$project" ]; then
    for kind in ps volume network image; do
      case "$kind" in
        ps) [ -z "$(docker ps -aq --filter "label=com.docker.compose.project=$project")" ] || left="$left containers" ;;
        *) [ -z "$(docker "$kind" ls -q --filter "label=com.docker.compose.project=$project")" ] || left="$left ${kind}s" ;;
      esac
    done
    if [ -n "$left" ]; then
      echo "FAIL: [ci-eb41cf] $project left$left after bin/down" >&2
      status=1
    else
      pass "[ci-eb41cf] the throwaway stack $project is removed"
    fi
  fi
  echo "E2E artifacts: $output"
  exit "$status"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

mkdir -p "$copy"
# Tracked files deleted in the working copy are skipped: copy what is there.
(cd "$root" && git ls-files -co --exclude-standard -z \
  | while IFS= read -r -d '' file; do [ ! -e "$file" ] || printf '%s\0' "$file"; done \
  | tar --null -T - -cf -) | tar -xf - -C "$copy"

# CI keeps no files, so a failed start shows the end of its log.
timed bin/up logged "$output/up.log" "$copy/bin/up" || { tail -n 20 "$output/up.log" >&2; fail 'bin/up'; }
project="$(sed -n 's/^COMPOSE_PROJECT_NAME=//p' "$copy/.env.session")"

# The suite's output stays in the job log, so it is timed by hand.
suite_start="$(date +%s)"
suite_status=0
"$copy/bin/e2e" 2>&1 | tee "$output/e2e.log" || suite_status=1
echo "TIME: bin/e2e $(($(date +%s) - suite_start))s"
if [ "$suite_status" != 0 ]; then
  fail '[ci-b7e2d3] the end-to-end suite failed; its report is in report/'
fi
pass '[ci-b7e2d3] the end-to-end suite passes against the throwaway stack'

# [ci-00f9af] The stack served the suite within its limits.
for id in $(docker ps -aq --filter "label=com.docker.compose.project=$project"); do
  read -r name memory oom restarts status health <<< "$(docker inspect -f '{{.Name}} {{.HostConfig.Memory}} {{.State.OOMKilled}} {{.RestartCount}} {{.State.Status}} {{with index .State "Health"}}{{.Status}}{{else}}none{{end}}' "$id")"
  [ "$memory" -gt 0 ] || fail "[ci-00f9af] $name has no memory limit"
  [ "$oom" = false ] && [ "$restarts" = 0 ] || fail "[ci-00f9af] $name was killed or restarted"
  [ "$status" = running ] && [ "$health" != unhealthy ] && [ "$health" != starting ] || fail "[ci-00f9af] $name is $status, $health"
done
pass '[ci-00f9af] every service ran limited, healthy and never killed'
