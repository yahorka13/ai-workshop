#!/usr/bin/env bash
# Point git at the repository hooks in .githooks/. Safe to run again.
#
#     bin/setup-git-hooks.sh
#
# core.hooksPath lives in the clone's shared config, so it covers every
# worktree. The hooks only save a round trip: CI enforces the same rules.
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
git -C "$ROOT" config core.hooksPath .githooks
echo "Git hooks enabled: core.hooksPath=.githooks"
