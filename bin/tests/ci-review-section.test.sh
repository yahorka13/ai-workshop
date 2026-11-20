# shellcheck shell=bash disable=SC2016,SC2154 # literal backticks of markdown headings
# bin/ci-review-section.sh, with a fake `gh` that reports the pull request's
# live draft state from $FAKE_IS_DRAFT and its body from $FAKE_BODY.

review_section() { "$BIN/ci-review-section.sh" "$@"; }

fake_gh() {
  mkdir -p fake-bin
  cat > fake-bin/gh <<'GH'
#!/usr/bin/env bash
case "$*" in
  "pr view 10 --json isDraft --jq .isDraft")
    [ -n "${FAKE_IS_DRAFT:-}" ] || { echo "gh: HTTP 502" >&2; exit 1; }
    echo "$FAKE_IS_DRAFT" ;;
  "pr view 10 --json body --jq .body")
    [ -n "${FAKE_BODY+set}" ] || { echo "unexpected: body read" >&2; exit 1; }
    printf '%b\n' "$FAKE_BODY" ;;
  *) echo "unexpected: gh $*" >&2; exit 1 ;;
esac
GH
  chmod +x fake-bin/gh
  PATH="$PWD/fake-bin:$PATH"
}

# [ci-96be04]
test_ready_pr_without_review_section_fails() {
  fake_gh
  FAKE_IS_DRAFT=false FAKE_BODY='## Summary\nx\n## Reviewers\ny\n### Review\nz' expect_fail review_section 10
  expect_output 'has no `## Review` section'
}

# [ci-5db1a6]
test_ready_pr_with_empty_review_section_fails() {
  fake_gh
  FAKE_IS_DRAFT=false FAKE_BODY='## Review\n\n   \n## Proof\nimg' expect_fail review_section 10
  expect_output '`## Review` section is empty'
}

# [ci-5db1a6]
test_ready_pr_with_trailing_empty_review_fails() {
  fake_gh
  FAKE_IS_DRAFT=false FAKE_BODY='## Summary\nx\n## Review\n\n' expect_fail review_section 10
  expect_output 'is empty'
}

# [ci-3617c4]
test_ready_pr_with_review_section_passes() {
  fake_gh
  FAKE_IS_DRAFT=false FAKE_BODY='## Summary\nx\n## Review\n\nNo findings.\n## Proof\ny' expect_pass review_section 10
  expect_output 'PR #10 records its review'
}

# [ci-3617c4]
test_crlf_review_section_with_subheading_passes() {
  fake_gh
  FAKE_IS_DRAFT=false FAKE_BODY='## Summary\r\nx\r\n## Review  \r\n\r\n### Deferred\r\n' expect_pass review_section 10
  expect_output 'records its review'
}

# [ci-5db1a6]
test_crlf_blank_lines_count_as_empty() {
  fake_gh
  FAKE_IS_DRAFT=false FAKE_BODY='## Review\r\n\r\n \r\n## Proof\r\n' expect_fail review_section 10
  expect_output 'is empty'
}

# [ci-3617c4]
test_review_as_last_section_passes() {
  fake_gh
  FAKE_IS_DRAFT=false FAKE_BODY='## Summary\nx\n## Review\n- fixed: y' expect_pass review_section 10
  expect_output 'records its review'
}

# [ci-120bd9]
test_draft_pr_passes_without_reading_the_body() {
  fake_gh
  FAKE_IS_DRAFT=true expect_pass review_section 10
  expect_output 'PR #10 is a draft'
}

# [ci-4b575e]
test_unknown_draft_state_fails_closed() {
  fake_gh
  FAKE_IS_DRAFT="" FAKE_BODY='## Review\nNo findings.' expect_fail review_section 10
  expect_output 'HTTP 502'
}

test_ci_review_section_rejects_wrong_arguments() {
  expect_fail review_section
  expect_output 'usage:'
}

# [ci-855c99] The review-section job runs in a workflow of its own that an
# edited description starts, with read-only permissions; the repository checks
# do not run on an edit.
test_review_section_reruns_on_description_edits() {
  local workflow="$ROOT/.github/workflows/pr-description.yml" types job event
  [ -f "$workflow" ] || fail 'no .github/workflows/pr-description.yml'
  types="$(grep -E '^    types: ' "$workflow" | tr -d '[],' | tr ' ' '\n')"
  for event in opened edited reopened synchronize ready_for_review; do
    grep -qxF "$event" <<< "$types" || fail "pr-description.yml does not run on $event"
  done
  grep -qxF 'permissions: {}' "$workflow" || fail 'pr-description.yml grants permissions workflow-wide'
  job="$(awk '/^  review-section:$/ { on = 1; next } /^  [a-z]/ { on = 0 } on' "$workflow")"
  [ -n "$job" ] || fail 'pr-description.yml has no review-section job'
  [ "$(sed -n '/^    permissions:$/,/^    [a-z]/p' <<< "$job" | grep -cE '^      [a-z-]+: ')" -eq 2 ] \
    || fail "the review-section job holds other permissions: $job"
  grep -qxF '      contents: read' <<< "$job" || fail 'the review-section job cannot read the repository'
  grep -qE '^      pull-requests: read( |$)' <<< "$job" || fail 'the review-section job cannot read the pull request'
  grep -qF 'run: bin/ci-review-section.sh "$PR"' <<< "$job" || fail 'the job does not run bin/ci-review-section.sh'
  ! grep -E '^    types: ' "$ROOT/.github/workflows/checks.yml" | grep -qw edited || fail 'checks.yml runs on description edits'
}

# [ci-4b575e]
test_unreadable_body_fails_closed() {
  fake_gh
  FAKE_IS_DRAFT=false expect_fail review_section 10
  expect_output 'unexpected: body read'
}
