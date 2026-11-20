#!/usr/bin/env bash
# CI's secret-scan step: scan the commits a pull request or push adds for
# secrets, with gitleaks in a pinned container.
set -euo pipefail

IMAGE=ghcr.io/gitleaks/gitleaks:v8.30.1@sha256:c00b6bd0aeb3071cbcb79009cb16a60dd9e0a7c60e2be9ab65d25e6bc8abbb7f

usage() {
  cat <<'EOF'
usage: bin/ci-secret-scan.sh <base> <head>
       bin/ci-secret-scan.sh --help

Scan the commits in <base>..<head> of the repository the current directory
is in for secrets, with gitleaks (the image named in this script) and its
default rules, plus a .gitleaks.toml at the root if one is ever needed.
With an empty or all-zeros <base> (a first push), every commit up to <head>
is scanned. The checkout is mounted read-only and found values are
redacted, so a secret never reaches the log.

Exit status: 0 nothing found, 1 a finding (file, line, commit and rule are
printed), 2 usage. Needs Docker; CI runs it in the supply-chain job.
EOF
}

[ "${1:-}" = --help ] && { usage; exit 0; }
[ "$#" -eq 2 ] || { usage >&2; exit 2; }
BASE="$1"
HEAD="$2"

ROOT="$(git rev-parse --show-toplevel)"
# A worktree's .git points into the main checkout's git directory: mount that
# too, at its own path, or gitleaks would scan nothing and report no leaks.
COMMON="$(cd "$(git rev-parse --git-common-dir)" && pwd -P)"
RANGE="$BASE..$HEAD"
# An empty or all-zeros base: every commit reachable from head.
[ -n "${BASE//0/}" ] || RANGE="$HEAD"

# The checkout belongs to another user than the container's: allow git to
# read it without writing any git config.
if ! docker run --rm \
  -e GIT_CONFIG_COUNT=1 -e GIT_CONFIG_KEY_0=safe.directory -e GIT_CONFIG_VALUE_0='*' \
  -v "$ROOT:/repo:ro" -v "$COMMON:$COMMON:ro" -w /repo "$IMAGE" git --no-banner --redact --verbose --exit-code 1 "--log-opts=$RANGE" /repo; then
  echo "secret-scan: remove the secret from the commit that added it, rotate it if it was real, or mark a false positive with a gitleaks:allow comment on its line" >&2
  exit 1
fi
