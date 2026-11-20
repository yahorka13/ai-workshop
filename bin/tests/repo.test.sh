# shellcheck shell=bash disable=SC2154
# bin/repo: the <owner>/<repo> of the checkout's origin remote, so no script or
# skill names the repository and every copy of the template works unchanged.

# expect_repo <url>: with origin at <url>, bin/repo prints o/r.
expect_repo() {
  git remote remove origin 2> /dev/null || true
  git remote add origin "$1"
  expect_pass "$BIN/repo"
  [ "$OUT" = "o/r" ] || fail "for $1 expected o/r, got: $OUT"
}

test_scp_style_ssh() {
  expect_repo git@github.com:o/r.git
}

test_https_with_and_without_git_suffix() {
  expect_repo https://github.com/o/r
  expect_repo https://github.com/o/r.git
}

test_ssh_url() {
  expect_repo ssh://git@github.com/o/r.git
}

test_trailing_slash() {
  expect_repo https://github.com/o/r/
}

test_no_origin_fails_with_fix() {
  expect_fail "$BIN/repo"
  expect_output "git remote add origin"
}

test_non_github_host_fails() {
  git remote add origin https://gitlab.com/o/r.git
  expect_fail "$BIN/repo"
  expect_output "not a GitHub repository"
}

# fake_ssh <hostname>: an ssh on PATH whose -G reports <hostname> for any host.
fake_ssh() {
  mkdir -p fake-bin
  # shellcheck disable=SC2016 # $1 belongs to the fake ssh
  printf '#!/usr/bin/env bash\n[ "$1" = -G ] || exit 255\necho "user git"\necho "hostname %s"\necho "port 22"\n' "$1" > fake-bin/ssh
  chmod +x fake-bin/ssh
  PATH="$PWD/fake-bin:$PATH"
}

# [repo-rules-21cc49]
test_ssh_host_alias() {
  fake_ssh github.com
  expect_repo git@gh-work:o/r.git
  expect_repo ssh://git@gh-work/o/r.git
}

# [repo-rules-abe2d1]
test_port_is_ignored() {
  expect_repo ssh://git@github.com:22/o/r.git
  expect_repo ssh://git@ssh.github.com:443/o/r.git
  expect_repo https://github.com:443/o/r
}

# [repo-rules-78e066]
test_alias_for_another_host_fails() {
  fake_ssh gitlab.com
  git remote add origin git@work:o/r.git
  expect_fail "$BIN/repo"
  expect_output "not a GitHub repository"
}

test_alias_for_ssh_over_https_port() {
  fake_ssh ssh.github.com
  expect_repo git@gh-443:o/r.git
}

test_https_user_part() {
  expect_repo https://u@github.com/o/r.git
}

test_alias_without_ssh_fails() {
  mkdir -p nossh
  local tool
  for tool in bash env git sed dirname; do ln -s "$(command -v "$tool")" "nossh/$tool"; done
  git remote add origin git@gh-work:o/r.git
  OUT="$(PATH="$PWD/nossh" "$BIN/repo" 2>&1)" && fail "expected failure: $OUT"
  expect_output "not a GitHub repository"
}
