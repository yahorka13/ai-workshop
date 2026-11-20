# shellcheck shell=bash disable=SC2154
# .gitattributes: scripts check out with LF on every platform (WSL and Windows
# checkouts with core.autocrlf break CRLF scripts), and tests and specs are
# collapsed in pull request diffs.

test_scripts_check_out_with_lf() {
  local path
  for path in bin/x.sh bin/tests/run.sh bin/repo .githooks/pre-commit; do
    expect_pass git -C "$ROOT" check-attr eol -- "$path"
    expect_output "eol: lf"
  done
}

test_tests_and_specs_are_marked_generated() {
  local path
  for path in bin/tests/x.test.sh openspec/specs/a/spec.md; do
    expect_pass git -C "$ROOT" check-attr linguist-generated -- "$path"
    expect_output "linguist-generated: true"
  done
}
