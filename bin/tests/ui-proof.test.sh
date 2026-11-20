# shellcheck shell=bash disable=SC2154
# bin/ci-ui-proof.sh against a fake gh that serves one PR.

setup_ui_proof() {
  mkdir -p "$REPO/fakes"
  cat > "$REPO/fakes/gh" <<'GH'
#!/usr/bin/env bash
set -eu
[ "${GH_FAIL:-}" != 1 ] || { echo 'gh: HTTP 502' >&2; exit 1; }
case "$*" in
  "pr view 42 --json isDraft --jq .isDraft") echo "${PR_DRAFT:-false}" ;;
  "api --paginate repos/{owner}/{repo}/pulls/42/files --jq .[].path") if [ -n "${PR_FILES_FILE:-}" ]; then cat "$PR_FILES_FILE"; else printf '%s\n' "$PR_FILES"; fi ;;
  "pr view 42 --json body --jq .body") if [ -n "${PR_BODY_FILE:-}" ]; then cat "$PR_BODY_FILE"; else printf '%s\n' "$PR_BODY"; fi ;;
  *) echo "fake gh: unexpected: $*" >&2; exit 2 ;;
esac
GH
  chmod +x "$REPO/fakes/gh"
  export PATH="$REPO/fakes:$PATH" PR_DRAFT=false PR_FILES='services/ui/src/pages/home/HomePage.tsx'
}

body_with_proof() {
  PR_BODY="$(printf '## Summary\n\nWhy.\n\n## Changes\n\n- What\n\n## Proof\n\n%s\n' "$1")"
  export PR_BODY
}

# [ci-5e8371]
test_ci_5e8371_ui_change_without_proof_fails() {
  setup_ui_proof
  body_with_proof 'Clicked around, all good.'
  expect_fail "$BIN/ci-ui-proof.sh" 42
  expect_output 'bin/e2e --proof'
  expect_output 'bin/proof-markdown HEAD'
}

# [ci-909d62]
test_ci_909d62_an_image_outside_proof_does_not_count() {
  setup_ui_proof
  PR_BODY="$(printf '## Summary\n\n![logo](https://example.com/a.png)\n\n## Proof\n\nNone.\n\n## Notes\n\n![x](https://example.com/b.png)\n')"
  export PR_BODY
  expect_fail "$BIN/ci-ui-proof.sh" 42
}

# [ci-49e43b]
test_ci_49e43b_images_and_videos_in_proof_pass() {
  setup_ui_proof
  local proof
  for proof in \
    '![home](https://github.com/owner/repo/blob/abc/openspec/changes/x/proof/home.png?raw=true)' \
    '<img width="600" src="https://example.com/shot.jpg">' \
    '<video src="https://example.com/run.mp4"></video>' \
    '- [run (video)](https://github.com/owner/repo/blob/abc/proof/run.webm?raw=true)' \
    'https://github.com/user-attachments/assets/0f1e2d3c-4b5a-6978-8a9b-0c1d2e3f4a5b'; do
    body_with_proof "$proof"
    expect_pass "$BIN/ci-ui-proof.sh" 42
  done
  # Line endings a browser editor leaves behind do not hide the section.
  PR_BODY="$(printf '## Summary\r\n\r\nWhy.\r\n\r\n## Proof\r\n\r\n![home](https://example.com/home.png)\r\n')"
  export PR_BODY
  expect_pass "$BIN/ci-ui-proof.sh" 42
}

# [ci-1bf16b]
test_ci_1bf16b_no_ui_source_change_passes() {
  setup_ui_proof
  export PR_FILES=$'bin/e2e\nservices/backend/src/app.ts\nservices/uikit/src/x.ts'
  body_with_proof 'Request/response excerpts.'
  expect_pass "$BIN/ci-ui-proof.sh" 42
  expect_output 'no visual proof required'
  export PR_FILES=$'services/ui/tests/unit/x.test.ts\nservices/ui/tooling/coverage-report.ts\nservices/ui/package.json\nservices/ui/nginx/nginx.conf'
  expect_pass "$BIN/ci-ui-proof.sh" 42
  expect_output 'no visual proof required'
}

# [ci-08ec7f]
test_ci_08ec7f_draft_skips_and_gh_errors_fail() {
  setup_ui_proof
  body_with_proof 'Nothing yet.'
  export PR_DRAFT=true
  expect_pass "$BIN/ci-ui-proof.sh" 42
  expect_output 'draft'
  export GH_FAIL=1
  expect_fail "$BIN/ci-ui-proof.sh" 42
}

# Far beyond a pipe buffer, with the match first, so a `grep -q` that exits
# early would cut off its writer. Files, not variables: Linux caps one
# environment string at 128 KiB.
test_long_proof_and_file_list_pass() {
  setup_ui_proof
  export PR_FILES_FILE="$REPO/files.txt" PR_BODY_FILE="$REPO/body.md"
  { echo services/ui/src/pages/home/HomePage.tsx
    awk 'BEGIN { for (i = 0; i < 40000; i++) print "services/backend/src/some/long/path/file" i ".ts" }'
  } > "$PR_FILES_FILE"
  { printf '## Summary\n\nWhy.\n\n## Proof\n\n![home](https://example.com/home.png)\n'
    awk 'BEGIN { for (i = 0; i < 40000; i++) print "Step " i " of the walkthrough, with no media on this line." }'
  } > "$PR_BODY_FILE"
  for _ in 1 2 3; do
    expect_pass "$BIN/ci-ui-proof.sh" 42
    expect_output 'its ## Proof section shows it'
  done
}

# [ci-c47acc]
test_ci_c47acc_only_generated_ui_files_need_no_proof() {
  setup_ui_proof
  export PR_FILES=$'services/backend/contracts/schema.graphql\nservices/ui/src/services/graphql/generated/graphql.ts'
  body_with_proof 'Request/response excerpts.'
  expect_pass "$BIN/ci-ui-proof.sh" 42
  expect_output 'generated'
}

# [ci-c47acc] The folder the check exempts is the one the ui's generation owns.
test_ci_c47acc_exempt_folder_is_the_generated_root() {
  local render="$ROOT/services/ui/tooling/contracts-render.ts" roots exempt
  roots="$(sed -nE 's/^export const graphqlTypesRoot = "([^"]+)";$/services\/ui\/\1\//p' "$render")"
  [ -n "$roots" ] || fail "no graphqlTypesRoot in $render"
  exempt="$(sed -nE 's/^generated=.(.*).$/\1/p' "$BIN/ci-ui-proof.sh" | tr '|' '\n' | sed 's/^\^//' | sort)"
  [ "$exempt" = "$roots" ] || fail "ci-ui-proof.sh exempts [$exempt], the ui generates [$roots]"
}

# [ci-87eec5]
test_ci_87eec5_a_hand_written_ui_file_beside_generated_ones_needs_proof() {
  setup_ui_proof
  export PR_FILES=$'services/ui/src/services/graphql/generated/graphql.ts\nservices/ui/src/services/graphql/health.ts'
  body_with_proof 'Request/response excerpts.'
  expect_fail "$BIN/ci-ui-proof.sh" 42
  expect_output 'bin/e2e --proof'
}

test_ui_proof_usage() {
  setup_ui_proof
  expect_fail "$BIN/ci-ui-proof.sh"
  expect_fail "$BIN/ci-ui-proof.sh" 42 extra
}

# GitHub's pr view lists only a PR's first 100 files; the UI's sort after them.
test_ci_5e8371_ui_files_past_the_first_hundred_need_proof() {
  setup_ui_proof
  export PR_FILES_FILE="$REPO/files.txt"
  { awk 'BEGIN { for (i = 0; i < 150; i++) print "bin/tests/f" i ".sh" }'
    echo services/ui/src/pages/home/HomePage.tsx
  } > "$PR_FILES_FILE"
  body_with_proof 'Clicked around, all good.'
  expect_fail "$BIN/ci-ui-proof.sh" 42
  expect_output 'bin/e2e --proof'
}
