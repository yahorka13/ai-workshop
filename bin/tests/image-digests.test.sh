# shellcheck shell=bash disable=SC2154,SC2016 # SC2016: fixture files hold literal dollar signs
# bin/check-image-digests.sh: every image reference in the tracked Dockerfiles,
# Compose files, workflows and bin/ scripts carries a digest.

DIGEST="sha256:$(printf '%064d' 0 | tr 0 a)"

check_digests() { "$BIN/check-image-digests.sh" "$REPO"; }

# Writes one reference of each kind with the given suffix after its tag, and
# commits them so they are tracked.
reference_fixture() {
  local pin="$1"
  mkdir -p services/a .github/workflows bin
  printf 'FROM oven/bun:1.4.3%s AS base\nRUN true\n' "$pin" > services/a/Dockerfile
  printf 'services:\n  db:\n    image: postgres:17.6-alpine%s # the database\n' "$pin" > docker-compose.yml
  printf 'jobs:\n  x:\n    steps:\n      - run: docker run --rm -v "$PWD:/mnt" -w /mnt koalaman/shellcheck:v0.11.0%s bin/x\n' "$pin" > .github/workflows/checks.yml
  printf '#!/usr/bin/env bash\nBUN_IMAGE=oven/bun:1.4.3%s\n' "$pin" > bin/x
  git add -A
  git commit -q -m "[1] Fixture"
}

# [repo-rules-a7ca79]
test_tag_only_references_fail() {
  reference_fixture ''
  expect_fail check_digests
  expect_output 'services/a/Dockerfile:1: oven/bun:1.4.3 is not pinned by digest'
  expect_output 'docker-compose.yml:3: postgres:17.6-alpine is not pinned by digest'
  expect_output '.github/workflows/checks.yml:4: koalaman/shellcheck:v0.11.0 is not pinned by digest'
  expect_output 'bin/x:2: oven/bun:1.4.3 is not pinned by digest'
  expect_output 'docker buildx imagetools inspect'
}

# [repo-rules-c1528d]
test_pinned_references_pass() {
  reference_fixture "@$DIGEST"
  printf 'FROM --platform=linux/amd64 node:24@%s\n' "$DIGEST" > services/a/Dockerfile.build
  git add -A
  git commit -q -m "[1] Platform"
  expect_pass check_digests
}

test_a_platform_flag_does_not_hide_the_image() {
  reference_fixture "@$DIGEST"
  printf 'FROM --platform=$BUILDPLATFORM node:24\n' > services/a/Dockerfile.build
  git add -A
  git commit -q -m "[1] Platform"
  expect_fail check_digests
  expect_output 'services/a/Dockerfile.build:1: node:24 is not pinned by digest'
}

# [repo-rules-8470e0]
test_stages_and_scratch_are_not_images() {
  reference_fixture "@$DIGEST"
  printf 'FROM oven/bun:1.4.3@%s AS base\nFROM base as runtime\nFROM scratch\n' "$DIGEST" > services/a/Dockerfile
  git add -A
  git commit -q -m "[1] Stages"
  expect_pass check_digests
}

# [repo-rules-02a22a]
test_short_digest_fails() {
  reference_fixture '@sha256:abc123'
  expect_fail check_digests
  expect_output 'services/a/Dockerfile:1: oven/bun:1.4.3@sha256:abc123 is not pinned by digest'
}

test_untracked_files_are_ignored() {
  reference_fixture "@$DIGEST"
  printf 'FROM node:24\n' > services/a/Dockerfile.local
  expect_pass check_digests
}

test_usage() {
  expect_pass "$BIN/check-image-digests.sh" --help
  expect_output 'docker buildx imagetools inspect'
  expect_fail "$BIN/check-image-digests.sh" a b
}

test_comments_and_locally_built_images_are_not_references() {
  reference_fixture "@$DIGEST"
  printf '#!/usr/bin/env bash\n# Options of docker run that take a value\nIMAGE="factory-e2e:$ID"\ndocker build -t "factory-e2e:$ID" .\ndocker run --rm "factory-e2e:$ID" test\n' > bin/y
  git add -A
  git commit -q -m "[1] Local"
  expect_pass check_digests
}

test_copy_from_an_image_needs_a_digest() {
  reference_fixture "@$DIGEST"
  printf 'FROM node:24@%s AS base\nCOPY --from=oven/bun:1.4.3 /bun /bun\nCOPY --from=base /a /a\nCOPY --from=0 /b /b\n' "$DIGEST" > services/a/Dockerfile.copy
  git add -A
  git commit -q -m "[1] Copy"
  expect_fail check_digests
  expect_output 'services/a/Dockerfile.copy:2: oven/bun:1.4.3 is not pinned by digest'
  [[ "$OUT" != *':3:'* && "$OUT" != *':4:'* ]] || fail "a stage was taken for an image: $OUT"
}

# [repo-rules-848a03]
test_end_to_end_scripts_are_checked_whatever_the_case() {
  reference_fixture "@$DIGEST"
  mkdir -p bin/tests
  printf '#!/usr/bin/env bash\npostgres_image=postgres:17-alpine # the database\n' > bin/tests/db.e2e.sh
  printf 'postgres_image=postgres:17-alpine\n' > bin/tests/fixture.test.sh
  git add -A
  git commit -q -m "[1] E2e"
  expect_fail check_digests
  expect_output 'bin/tests/db.e2e.sh:2: postgres:17-alpine is not pinned by digest'
  [[ "$OUT" != *fixture.test.sh* ]] || fail "a test fixture was checked: $OUT"
}
