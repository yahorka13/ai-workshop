# ci Specification

## Purpose
What CI runs on pull requests and pushes to main: the repository checks, every service's gates, the stack proofs, cancellation, and the pull request and issue workflows.

## Requirements

### Requirement: The change-archived step checks only a ready pull request
The `change-archived` step of `repo-checks` SHALL check the archive only when the PR is not a draft, reading the draft state when the step runs, and failing when that state cannot be read.

#### Scenario: [ci-10858b] Unarchived change fails a ready PR
- **WHEN** a change-branch PR is marked ready for review while its change is not archived
- **THEN** the `change-archived` step of `repo-checks` fails

#### Scenario: [ci-9d2e23] Draft PR skips the archive check
- **WHEN** a change-branch PR is a draft
- **THEN** the `change-archived` step of `repo-checks` passes without checking the archive and says the PR is a draft

#### Scenario: [ci-4d6562] Ready state is read when the check runs
- **WHEN** a commit is pushed and the PR is marked ready for review seconds later
- **THEN** the `change-archived` step checks the archive for that commit, because it reads the PR's current draft state rather than the event's
- **AND** the ready-for-review run waits for the push's run instead of cancelling it, and both run to the end

### Requirement: CI runs every service's gates on every pull request
CI SHALL run `bin/check <service>` for every service with a checks target, each as its own job named after the service, through one reusable workflow.

#### Scenario: [ci-5c3c03] The backend's gates run in CI
- **WHEN** CI runs on a pull request or a push to `main`
- **THEN** a `backend-checks` job calls `.github/workflows/service-check.yml` with `service: backend`, which runs `bin/check backend` on `ubuntu-24.04` within 10 minutes

#### Scenario: [ci-0ff7ea] The UI's gates run in CI
- **WHEN** CI runs on a pull request or a push to `main`
- **THEN** a `ui-checks` job calls `.github/workflows/service-check.yml` with `service: ui`, which runs `bin/check ui` on `ubuntu-24.04` within 10 minutes

### Requirement: CI runs the migration checks
The `repo-checks` job SHALL run a `migrations` step: the expand-only check on every run, and the immutable check against the pull request's base on pull requests.

#### Scenario: [ci-68ac38] The migration checks run in repo-checks
- **WHEN** CI runs on a pull request
- **THEN** the `migrations` step of `repo-checks` runs `bin/check-migrations-expand-only.sh` and `bin/check-migrations-immutable.sh` with the base and head commits

### Requirement: CI proves the migration runner on Postgres
CI SHALL run `bin/tests/db-migrate.e2e.sh` on every pull request and push to `main`, in its own job.

#### Scenario: [ci-e699ce] The migration proof runs in CI
- **WHEN** CI runs on a pull request
- **THEN** a `db-migrate-proof` job runs `bin/tests/db-migrate.e2e.sh`

### Requirement: CI proves bin/check blocks the network
CI SHALL run `bin/tests/check-offline.e2e.sh` on every pull request and push to `main`, in its own job.

#### Scenario: [ci-ba1f03] The offline proof runs in CI
- **WHEN** CI runs on a pull request
- **THEN** a `check-offline-proof` job runs `bin/tests/check-offline.e2e.sh` on `ubuntu-24.04` within 10 minutes

### Requirement: The review-section check requires a review in a ready pull request
The `review-section` check SHALL fail a pull request that is not a draft unless its body has a `## Review` heading followed by at least one non-blank line before the next `## ` heading, reading the draft state and body when the check runs and failing when they cannot be read. Drafts pass.

#### Scenario: [ci-96be04] Ready PR without a Review section fails
- **WHEN** a pull request is ready for review and its body has no `## Review` heading
- **THEN** the `review-section` check fails and says the `## Review` section is missing

#### Scenario: [ci-5db1a6] Ready PR with an empty Review section fails
- **WHEN** a pull request is ready for review and its `## Review` heading has only blank lines before the next `## ` heading or the end
- **THEN** the `review-section` check fails and says the `## Review` section is empty

#### Scenario: [ci-3617c4] Ready PR with a Review section passes
- **WHEN** a pull request is ready for review and its `## Review` section lists findings or says `No findings.`
- **THEN** the `review-section` check passes

#### Scenario: [ci-120bd9] Draft PR skips the review check
- **WHEN** a pull request is a draft
- **THEN** the `review-section` check passes without reading the body and says the PR is a draft

#### Scenario: [ci-4b575e] Unreadable PR state fails the review check
- **WHEN** the pull request's draft state and body cannot be read from GitHub
- **THEN** the `review-section` check fails

### Requirement: Editing a pull request's description re-runs the review check
The `review-section` check SHALL run when a pull request is opened, reopened, marked ready for review or has its description edited, in a workflow of its own, so that fixing the description re-runs only that check.

#### Scenario: [ci-855c99] Editing the description re-runs the review check
- **WHEN** the description of a ready pull request is edited
- **THEN** the `review-section` check runs again on the new body, and the repository checks do not

### Requirement: The eof-newline step checks the files a range changed
The `eof-newline` step of `repo-checks` SHALL check the files added, copied, modified or renamed between a pull request's base and head, or between a push's previous and new head on `main`.

#### Scenario: [ci-3c9837] Only changed files are checked
- **WHEN** `bin/ci-eof-newline.sh <base> <head>` runs on a range that adds a file without a final newline, while an untouched tracked file also lacks one
- **THEN** it fails and names only the added file

### Requirement: A first push checks every tracked file
When a push has no previous head, its `before` being all zeros, the `eof-newline` step SHALL check every tracked file.

#### Scenario: [ci-a31d7f] A fresh copy's first push is checked
- **WHEN** `bin/ci-eof-newline.sh 0000000000000000000000000000000000000000 <head>` runs on a tree holding a tracked file without a final newline
- **THEN** it fails and names that file

### Requirement: The ui-proof check requires visual proof of a UI change
The `ui-proof` check SHALL fail a pull request that is not a draft and changes a hand-written file under `services/ui/src/` unless its `## Proof` section shows a markdown image, an `<img>` or `<video>` tag, a link to a `.png`, `.jpg`, `.gif`, `.webm` or `.mp4` file, or a GitHub upload.

#### Scenario: [ci-5e8371] A UI change without proof fails
- **WHEN** a ready pull request changes `services/ui/src/pages/home/HomePage.tsx` and its `## Proof` section has only text
- **THEN** the `ui-proof` check fails and says to capture proof with `bin/e2e --proof` and paste `bin/proof-markdown HEAD` into `## Proof`

#### Scenario: [ci-909d62] An image outside the Proof section does not count
- **WHEN** a ready pull request changes `services/ui/src/` and its only image is under `## Summary`
- **THEN** the `ui-proof` check fails

#### Scenario: [ci-49e43b] An image or a video in Proof passes
- **WHEN** a ready pull request changes `services/ui/src/` and its `## Proof` section has a markdown image, an `<img>` tag, a `.webm` link or a GitHub upload link
- **THEN** the `ui-proof` check passes

### Requirement: The ui-proof check needs no proof without a hand-written UI change
The `ui-proof` check SHALL pass a pull request that changes nothing under `services/ui/src/` or only files generated from contracts there.

#### Scenario: [ci-1bf16b] No UI source change passes
- **WHEN** a ready pull request changes only `services/ui/tests/`, `services/ui/tooling/` or files outside `services/ui/`
- **THEN** the `ui-proof` check passes and says no visual proof is required

#### Scenario: [ci-c47acc] Only generated UI files need no proof
- **WHEN** a ready pull request's only files under `services/ui/src/` are in `services/ui/src/services/graphql/generated/`
- **THEN** the `ui-proof` check passes

#### Scenario: [ci-87eec5] A hand-written file beside generated ones needs proof
- **WHEN** a ready pull request changes generated files and `services/ui/src/services/graphql/health.ts`, with no image in `## Proof`
- **THEN** the `ui-proof` check fails

### Requirement: The ui-proof check reads the pull request when it runs
The `ui-proof` check SHALL read the pull request's draft state, files and body from GitHub when it runs, passing a draft and failing when they cannot be read.

#### Scenario: [ci-08ec7f] Draft skips and an unreadable PR fails
- **WHEN** the pull request is a draft, or its state cannot be read from GitHub
- **THEN** the `ui-proof` check passes saying the PR is a draft, or fails, respectively

### Requirement: The pr-body check enforces the title
The `pr-body` check SHALL fail a pull request, draft or ready, whose title does not start with the prefix its head branch dictates followed by a space and then a capital letter or a lowercase `<scope>: ` and a capital letter.

#### Scenario: [ci-2ddea6] A title without its prefix fails
- **WHEN** a pull request from branch `12-a3f9c1-slots` is titled `Allocate slots`
- **THEN** the `pr-body` check fails and says the title must start with `[12][a3f9c1] `

#### Scenario: [ci-ac8098] A long title with its prefix passes
- **WHEN** a pull request from branch `12-a3f9c1-slots` is titled `[12][a3f9c1] Allocate isolated session slots per worktree so that several agents can run stacks side by side`
- **THEN** the title passes the `pr-body` check

### Requirement: The pr-body check enforces the sections
The `pr-body` check SHALL fail a pull request whose body lacks `## Summary`, `## Changes` and `## Proof` in that order, other sections allowed between them.

#### Scenario: [ci-3c3413] Missing sections fail together
- **WHEN** a pull request's body has `## Summary` and `## Changes` but no `## Proof`, and no `Closes` line
- **THEN** the `pr-body` check fails and reports both the missing `## Proof` and the missing `Closes` line in one run

#### Scenario: [ci-c9f2b8] Sections out of order fail
- **WHEN** a pull request's body has `## Proof` before `## Changes`
- **THEN** the `pr-body` check fails and says the order

#### Scenario: [ci-cbbebe] Extra sections pass
- **WHEN** a pull request's body has `## Summary`, `## Changes`, `## Proof` and `## Review`, and a code block of shell commands
- **THEN** the body passes the `pr-body` check

### Requirement: The pr-body check enforces the issue line
The `pr-body` check SHALL fail a pull request whose title names issue N and whose body has no line starting `Closes #N`, a `[HOTFIX]` title needing none.

#### Scenario: [ci-6b0a4e] A hotfix needs no issue line
- **WHEN** a pull request titled `[HOTFIX] Restore the health check` has no `Closes` line
- **THEN** the body passes the `pr-body` check

#### Scenario: [ci-5c19b5] Closes must name the exact issue
- **WHEN** a pull request titled `[12] ...` has only `Closes #123`
- **THEN** the `pr-body` check fails and asks for `Closes #12`

### Requirement: The pr-body check matches the change lines to the diff
The `pr-body` check SHALL fail a pull request whose body does not list exactly one ``Change: `<id>` `` line for each change of its issue that its diff adds or edits, active or archived.

#### Scenario: [ci-15a4f9] A missing change line fails
- **WHEN** a pull request for issue 12 adds `openspec/changes/12-a3f9c1-slots/` and its body has no ``Change: `12-a3f9c1-slots` `` line
- **THEN** the `pr-body` check fails and names the change

#### Scenario: [ci-257c8c] An archived change counts
- **WHEN** the diff adds `openspec/changes/archive/2026-11-17-12-a3f9c1-slots/` and the body lists ``Change: `12-a3f9c1-slots` ``
- **THEN** the change lines pass the `pr-body` check

#### Scenario: [ci-dff6f4] A line for an untouched change fails
- **WHEN** the body lists ``Change: `12-bbbbbb-other` `` and the diff does not touch that change
- **THEN** the `pr-body` check fails and says to remove the line

### Requirement: The pr-body check rejects pasted shell leftovers
The `pr-body` check SHALL fail a pull request whose body has a test-plan heading, a heredoc leftover outside a code block (a line that is only `EOF`, or `$(cat <<`), or a path in one person's home directory.

#### Scenario: [ci-7e21a7] A test-plan heading fails
- **WHEN** a pull request's body has a `## Test plan` heading
- **THEN** the `pr-body` check fails and says CI is the test plan

#### Scenario: [ci-d22c12] Heredoc leftovers fail outside code blocks
- **WHEN** a pull request's body has a line that is only `EOF` outside a code block
- **THEN** the `pr-body` check fails and says to pass the body with `--body-file`
- **AND** the same line inside a fenced code block passes

#### Scenario: [ci-12ead1] A home path fails
- **WHEN** a pull request's body names a path under a person's home folder
- **THEN** the `pr-body` check fails and names the line

### Requirement: Editing a pull request's description re-runs the proof and body checks
The `ui-proof` and `pr-body` checks SHALL run in the pull request description workflow, next to `review-section`, on every pull request event that workflow handles, so editing the description re-runs them without the repository checks.

#### Scenario: [ci-fbf59d] The description workflow runs the proof and body checks
- **WHEN** `.github/workflows/pr-description.yml` is read
- **THEN** it has `ui-proof` and `pr-body` jobs that run `bin/ci-ui-proof.sh` and `bin/ci-pr-body.sh` with the pull request's number, on `opened`, `edited`, `reopened`, `synchronize` and `ready_for_review`
- **AND** the `pr-body` job checks out the pull request's head with full history

### Requirement: CI runs the end-to-end suite's gates
CI SHALL run `bin/e2e --gates` on every pull request and push to `main` in an `e2e-gates` job within 10 minutes.

#### Scenario: [ci-f24772] The suite's gates run in CI
- **WHEN** `.github/workflows/checks.yml` is read
- **THEN** an `e2e-gates` job runs `bin/e2e --gates` on `ubuntu-24.04` with `timeout-minutes: 10`

### Requirement: CI runs the end-to-end suite against a throwaway stack
CI SHALL run `bin/tests/e2e-stack.e2e.sh` on every pull request and push to `main` in an `e2e` job within 10 minutes, removing the stack even when the job is cancelled.

#### Scenario: [ci-3bc641] The suite runs in CI
- **WHEN** `.github/workflows/checks.yml` is read
- **THEN** an `e2e` job runs `bin/tests/e2e-stack.e2e.sh` on `ubuntu-24.04` with `timeout-minutes: 10`, and an `always()` step runs `bin/down` in every worktree the proof copied

#### Scenario: [ci-b7e2d3] The suite passes against a fresh stack
- **WHEN** `bin/tests/e2e-stack.e2e.sh` runs
- **THEN** it copies the checkout, starts its stack with `bin/up`, runs `bin/e2e` against it and the suite passes

### Requirement: The throwaway stack leaves nothing behind
`bin/tests/e2e-stack.e2e.sh` SHALL always remove its stack with `bin/down` and fail when any container, volume, network or the stack's own image remains.

#### Scenario: [ci-eb41cf] The stack goes whether the suite passed or not
- **WHEN** `bin/tests/e2e-stack.e2e.sh` ends, passed or failed
- **THEN** it has run `bin/down` in its copy and checked that no container, volume, network or image of that stack's project remains

### Requirement: The throwaway stack runs within its limits
`bin/tests/e2e-stack.e2e.sh` SHALL fail when a container of its stack was not running and healthy after the suite, was killed for memory, or restarted.

#### Scenario: [ci-00f9af] Every service ran healthy and was never killed
- **WHEN** the suite has passed against the throwaway stack
- **THEN** every container of the stack is running, not unhealthy, has a memory limit, was never OOM-killed and has no restarts

### Requirement: A failed suite run in CI keeps its evidence
The `e2e` job SHALL upload the Playwright report, each service's log and the proof's step logs as an artifact when it fails.

#### Scenario: [ci-b611c0] A failure uploads the report and logs
- **WHEN** the `e2e` job fails
- **THEN** it uploads `tmp/e2e-stack/*/report/`, `tmp/e2e-stack/*/logs/` and `tmp/e2e-stack/*/*.log`, kept 14 days, and the job log shows each container's state

### Requirement: CI's image builds use the GitHub Actions cache
The `e2e` and `e2e-gates` jobs SHALL build their images with `FACTORY_BUILD_CACHE=gha` on a BuildKit builder that can reach GitHub's cache service.

#### Scenario: [ci-384a85] The e2e jobs build with the cache
- **WHEN** `.github/workflows/checks.yml` is read
- **THEN** the `e2e` and `e2e-gates` jobs set `FACTORY_BUILD_CACHE: gha`, set up a Buildx builder and expose the Actions runtime to their steps, each action pinned by commit SHA

### Requirement: bin/e2e builds with the cache on request
`bin/e2e` SHALL build the suite's image with BuildKit's GitHub Actions cache, scope `e2e`, when `FACTORY_BUILD_CACHE=gha`, and with Docker's default build otherwise.

#### Scenario: [ci-ed7467] The suite's image uses the cache in CI
- **WHEN** `bin/e2e --gates` runs with `FACTORY_BUILD_CACHE=gha`
- **THEN** it builds the image with `docker buildx build --load` and `--cache-from` and `--cache-to` of `type=gha` with scope `e2e`
- **AND** without the setting it builds with `docker build`

### Requirement: Nothing else runs mutation testing
No pull request check, `bin/check` or git hook SHALL run `bin/mutate`, since a run takes hours; the instructions tell agents not to run it either, and say how to start a run in CI.

#### Scenario: [ci-bebd29] Nothing else runs mutation testing
- **WHEN** a pull request runs its checks, `bin/check` runs, or an agent follows the Definition of done or `/work`
- **THEN** no check runs `bin/mutate`, and the instructions say not to run it
- **AND** AGENTS.md and `bin/mutate --help` show `gh workflow run mutation -R "$(bin/repo)"`, and no instruction says mutation testing runs nightly

### Requirement: Mutation testing runs on demand
The `mutation` workflow SHALL run only when a person starts it by hand (`gh workflow run mutation -R "$(bin/repo)"`), never on a schedule, a push or a pull request. It runs `bin/mutate backend` and `bin/mutate ui` over the whole source of the ref it was started on, `main` by default, on GitHub-hosted runners, showing each run's score and surviving mutants in its summary and keeping its reports even when it fails.

#### Scenario: [ci-f3e6f4] Mutation testing runs when started by hand
- **WHEN** a person starts the `mutation` workflow by hand
- **THEN** it runs `bin/mutate backend` and `bin/mutate ui` on the ref it was started on, each run's summary shows the score and surviving mutants, and its reports are uploaded
- **AND** its `run:` steps read the service from `env:`, not from an inline `${{ matrix.service }}`

#### Scenario: [ci-4d3abd] Mutation testing never starts on its own
- **WHEN** `.github/workflows/mutation.yml` is read
- **THEN** its only trigger is `workflow_dispatch`: it has no `schedule`, `push` or `pull_request` trigger

### Requirement: The mutation harness is proven with each mutation run
The `mutation` workflow SHALL run `bin/tests/mutate.e2e.sh`, the Docker-backed proof of `bin/mutate`, and keep its logs.

#### Scenario: [ci-e17078] The harness proof runs with each mutation run
- **WHEN** the `mutation` workflow runs
- **THEN** a job runs `bin/tests/mutate.e2e.sh` and uploads its logs

### Requirement: CI scans pushed commits for secrets
CI SHALL scan the commits of every pull request and push to `main` for secrets, every commit up to the head on a first push, and fail on a finding with its file, line, commit and rule, never printing the secret's value.

#### Scenario: [ci-41bb45] A committed key fails the scan without printing it
- **WHEN** a commit in the range adds a file holding a private key or a cloud access key
- **THEN** the secret-scan step fails naming that file, line and commit, and its output does not contain the key

#### Scenario: [ci-ae9a14] A clean range passes
- **WHEN** no commit in the range adds a secret
- **THEN** the secret-scan step passes

#### Scenario: [ci-9e7f46] A first push scans every commit
- **WHEN** the scan's base is empty or all zeros
- **THEN** it scans every commit up to the head

### Requirement: CI audits every service's dependencies
CI SHALL audit the locked dependencies of every service with a lockfile on every pull request and push to `main`, and fail when any has a known vulnerability of critical severity, naming the service and the package; every service is audited even after one fails.

#### Scenario: [ci-f9b512] A critical advisory fails the audit
- **WHEN** a service's lockfile locks a package version with a known critical advisory
- **THEN** the dependency-audit step fails naming that service and package, and still audits the other services

#### Scenario: [ci-37c8df] High advisories are reported without failing
- **WHEN** no service's lockfile locks a package with a known critical advisory, and one locks a package with a high one
- **THEN** the dependency-audit step prints the high advisory and passes
