# shellcheck shell=bash disable=SC2154
# bin/tests/proof-steps.sh: timed steps and their logs.

test_timed_prints_seconds_and_keeps_status() {
  # shellcheck source=bin/tests/proof-steps.sh
  source "$ROOT/bin/tests/proof-steps.sh"
  expect_fail timed 'a failing step' false
  expect_output 'TIME: a failing step 0s'
  expect_pass timed 'a sleeping step' sleep 1
  [[ "$OUT" =~ TIME:\ a\ sleeping\ step\ [12]s ]] || fail "expected about 1s: $OUT"
  expect_pass timed 'a logged step' logged "$REPO/step.log" echo into the log
  expect_output 'TIME: a logged step 0s'
  [[ "$OUT" != *'into the log'* ]] || fail "the step's output reached the job log: $OUT"
  grep -qx 'into the log' "$REPO/step.log" || fail 'the step did not log'
}
