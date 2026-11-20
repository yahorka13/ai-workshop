# shellcheck shell=bash
# Steps of the stack proofs, timed so a CI log shows where its time went.
# Source it from a proof with `# shellcheck source=bin/tests/proof-steps.sh`.
#
#     timed <step> <command...>       # runs it, prints `TIME: <step> <n>s`, keeps its status
#     logged <log> <command...>       # runs it with its output in <log>, for timed

timed() {
  local step="$1" start status=0
  shift
  start="$(date +%s)"
  "$@" || status=$?
  echo "TIME: $step $(($(date +%s) - start))s"
  return "$status"
}

logged() {
  local log="$1"
  shift
  "$@" > "$log" 2>&1
}
