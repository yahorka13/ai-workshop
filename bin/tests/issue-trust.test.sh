# shellcheck shell=bash disable=SC2154
# bin/issue-trust, with a fake `gh` that answers the issue's author from
# $FAKE_AUTHOR, its comment authors from $FAKE_COMMENTERS (space-separated),
# and each login's push access from $FAKE_PUSHERS (space-separated
# <login>:<role> pairs; anyone else cannot push), fails every API call when
# $FAKE_API_FAILS is set and the lookups of the logins in $FAKE_API_FAILS_FOR,
# and logs every call to gh.log, one line per call with
# each argument in brackets.

issue_trust() { "$BIN/issue-trust" "$@"; }

fake_trust_gh() {
  mkdir -p fake-bin
  cat > fake-bin/gh <<'GH'
#!/usr/bin/env bash
{ printf '[%s]' "$@"; echo; } >> gh.log
case "$1 $2" in
  "issue view")
    [ -z "${FAKE_VIEW_EXIT:-}" ] || { echo "To get started with GitHub CLI, please run:  gh auth login" >&2; exit "$FAKE_VIEW_EXIT"; }
    case "$*" in
      *"--json author"*) echo "$FAKE_AUTHOR" ;;
      *"--json comments"*) for c in ${FAKE_COMMENTERS:-}; do echo "$c"; done ;;
      *) echo "unexpected: gh $*" >&2; exit 1 ;;
    esac ;;
  api\ repos/o/r/collaborators/*)
    [ -z "${FAKE_API_FAILS:-}" ] || { echo "HTTP 403: Must have push access to view repository collaborators." >&2; exit 1; }
    login="${2#repos/o/r/collaborators/}"; login="${login%/permission}"
    for bad in ${FAKE_API_FAILS_FOR:-}; do [ "$bad" = "$login" ] && { echo "HTTP 404: Not Found" >&2; exit 1; }; done
    for pair in ${FAKE_PUSHERS:-}; do
      [ "${pair%%:*}" = "$login" ] && { printf 'true\t%s\n' "${pair#*:}"; exit 0; }
    done
    printf 'false\t\n' ;;
  *) echo "unexpected: gh $*" >&2; exit 1 ;;
esac
GH
  chmod +x fake-bin/gh
  PATH="$PWD/fake-bin:$PATH"
  : > gh.log
  git remote add origin git@github.com:o/r.git 2> /dev/null || true
  export FAKE_AUTHOR=ana FAKE_PUSHERS='ana:write' FAKE_COMMENTERS=''
}

# expect_status <status> <command>... runs the command, keeping its combined
# output in $OUT, and fails unless it exits with <status>.
expect_status() {
  local want="$1" status=0
  shift
  OUT="$("$@" 2>&1)" || status=$?
  [ "$status" = "$want" ] || fail "expected exit $want, got $status: $*"$'\n'"$OUT"
}

# [agent-workflow-4ff0b0]
test_pusher_is_trusted() {
  fake_trust_gh
  expect_pass issue_trust 12
  expect_output "trusted: @ana (write)"
  grep -qF '[issue][view][12][-R][o/r]' gh.log || fail "the issue was not read from o/r"$'\n'"$(cat gh.log)"
}

# [agent-workflow-a6eb04]
test_reader_is_untrusted() {
  fake_trust_gh
  FAKE_AUTHOR=eve expect_status 4 issue_trust 12
  expect_output "untrusted: @eve (none) cannot push to o/r"
}

# [agent-workflow-a6eb04]
test_bot_author_is_untrusted() {
  fake_trust_gh
  FAKE_AUTHOR='dependabot[bot]' expect_status 4 issue_trust 12
  expect_output "untrusted: @dependabot[bot]"
  grep -qF 'collaborators/dependabot[bot]/permission' gh.log || fail "the bot's login was not looked up verbatim"$'\n'"$(cat gh.log)"
}

# [agent-workflow-d80f96]
test_usage_errors() {
  fake_trust_gh
  for args in '' abc 0 '--nope 3' '3 4' '3 --comments --comments'; do
    # shellcheck disable=SC2086 # split the argument list on purpose
    expect_status 2 issue_trust $args
    expect_output "usage: bin/issue-trust"
  done
  [ ! -s gh.log ] || fail "a usage error called gh"$'\n'"$(cat gh.log)"
}

test_help_needs_no_gh() {
  PATH="/usr/bin:/bin" expect_pass issue_trust --help
  expect_output "usage: bin/issue-trust"
}

# [agent-workflow-9ce42c]
test_untrusted_commenters_are_listed() {
  fake_trust_gh
  FAKE_PUSHERS='ana:admin bob:write' FAKE_COMMENTERS='bob eve eve' expect_pass issue_trust 12 --comments
  [ "$(grep -c '^untrusted-comment: ' <<< "$OUT")" = 1 ] || fail "expected one untrusted commenter"$'\n'"$OUT"
  expect_output "untrusted-comment: @eve"
  [[ "$OUT" != *"@bob"* ]] || fail "a collaborator was listed"$'\n'"$OUT"
}

test_no_comments_lists_nobody() {
  fake_trust_gh
  expect_pass issue_trust 12 --comments
  [[ "$OUT" != *"untrusted-comment"* ]] || fail "nobody commented"$'\n'"$OUT"
}

test_comments_flag_in_either_position() {
  fake_trust_gh
  export FAKE_COMMENTERS=eve
  expect_pass issue_trust --comments 12
  local before="$OUT"
  expect_pass issue_trust 12 --comments
  [ "$OUT" = "$before" ] || fail "the flag's position changed the output"$'\n'"$before"$'\n'"$OUT"
}

# [agent-workflow-9ce42c]
test_untrusted_author_with_comments_still_exits_4() {
  fake_trust_gh
  FAKE_AUTHOR=eve FAKE_COMMENTERS='ana mallory' expect_status 4 issue_trust 12 --comments
  expect_output "untrusted: @eve"
  expect_output "untrusted-comment: @mallory"
}

test_lookup_failure_is_not_trusted() {
  fake_trust_gh
  local status=0
  OUT="$(FAKE_API_FAILS=1 issue_trust 12 2>&1)" || status=$?
  [ "$status" != 0 ] && [ "$status" != 4 ] || fail "a failed lookup exited $status"$'\n'"$OUT"
}

# gh exits 4 when it is not signed in and 2 when cancelled: neither may read as
# "untrusted" or a usage error.
test_gh_failure_statuses_are_not_verdicts() {
  fake_trust_gh
  local code status
  for code in 2 4; do
    status=0
    OUT="$(FAKE_VIEW_EXIT=$code issue_trust 12 2>&1)" || status=$?
    [ "$status" != 0 ] && [ "$status" != 2 ] && [ "$status" != 4 ] || fail "gh exit $code became exit $status"$'\n'"$OUT"
  done
}

# A commenter whose lookup fails, such as an app's bot account, is listed as
# untrusted; the verdict on the trusted author stands.
test_failed_commenter_lookup_lists_the_commenter() {
  fake_trust_gh
  FAKE_COMMENTERS='robot eve' FAKE_API_FAILS_FOR=robot expect_pass issue_trust 12 --comments
  expect_output "trusted: @ana (write)"
  expect_output "untrusted-comment: @robot"
  expect_output "untrusted-comment: @eve"
}
