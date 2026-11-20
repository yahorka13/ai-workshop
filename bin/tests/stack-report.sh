# shellcheck shell=bash
# What a failed run's stack looked like, before bin/down removes it: every
# service's timestamped log in <dir>/logs/, and on stdout each container's
# state and the last lines of the backend's log. It never fails, so a stack
# that never started still lets the run report its own error.
# Source it with `# shellcheck source=bin/tests/stack-report.sh`.
#
#     stack_report <compose> <dir>   # <compose>: the stack's bin/compose
stack_report() {
  local compose="$1" dir="$2" service id ids
  mkdir -p "$dir/logs" || return 0
  for service in $("$compose" ps -a --format '{{.Service}}' 2> /dev/null); do
    "$compose" logs --no-color --timestamps "$service" > "$dir/logs/$service.log" 2> /dev/null || true
  done
  ids="$("$compose" ps -aq 2> /dev/null)" || ids=""
  if [ -z "$ids" ]; then
    echo '== no containers to report =='
    return 0
  fi
  echo '== stack state =='
  for id in $ids; do
    docker inspect -f '{{.Name}} status={{.State.Status}} exit={{.State.ExitCode}} restarts={{.RestartCount}} oom={{.State.OOMKilled}}' "$id" 2> /dev/null \
      || echo "$id: cannot inspect"
  done
  if [ -f "$dir/logs/backend.log" ]; then
    echo '== last 200 lines of backend (full log: logs/backend.log) =='
    tail -n 200 "$dir/logs/backend.log"
  fi
  return 0
}
