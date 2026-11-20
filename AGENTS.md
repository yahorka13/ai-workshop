# AGENTS.md

How to work in this repository. [docs/principles.md](docs/principles.md) says why; [docs/product.md](docs/product.md) says what we are building. When this file and the principles disagree, fix this file. A rule a check enforces names the check; the rest are judgement.

## Basics

- English everywhere: code, comments, docs, commits, conversation.
- Every file ends with a newline: the pre-commit hook adds a missing one, CI's `eof-newline` fails without it.
- Do not change user-facing copy unless asked.
- A comment about one variable or setting goes on its line, to the right, in a few words: `MAX: 120 # 4x the default, for e2e`. Comments above a line are for a group or a block.
- Numbers in YAML and env files are unquoted; quote only values YAML would misread, such as `true`, `yes` or `0123`, and mark a number a schema needs as a string with `# string: <reason>` (`conventions`).
- `README.md` is the newcomer's guide: the idea, installation, the first issue, a repository map and a study guide. No runbooks; a command's flags and details live in its `--help`.
- Never edit generated files by hand: generated skills, contracts and clients. Change the source and regenerate.
- The repository is whatever `origin` points at: every copy of this template has its own. Pass `-R "$(bin/repo)"` to every `gh` command, never a literal name (`conventions`).
- Shared files name no path in one person's home directory (`home-paths`, the pre-commit hook).
- When planning is requested, deliver a plan within minutes; present what you know and ask targeted questions rather than exploring indefinitely.

## Layout

| Path | What lives there |
|---|---|
| `services/<name>/` | One isolated service: own `package.json`, lockfile, config, Dockerfile and `AGENTS.md` |
| `services/e2e/` | Black-box Playwright end-to-end tests against a running stack; ships no application code |
| `openspec/specs/` | How the system behaves today |
| `openspec/changes/` | In-flight changes; `archive/` holds merged ones |
| `docs/` | Principles and product brief |
| `bin/` | Pinned repo tools and scripts, and their tests in `bin/tests/`; service runtimes are versioned in each service package |
| `.githooks/` | The git hooks `bin/setup` enables |

Service-specific rules live in `services/<name>/AGENTS.md`. Read it before touching that service.

## Workflow

Start every task with `/work <issue>`. No issue, no code: create the issue first with `/ticket`, which files it with `gh issue create -R "$(bin/repo)"`. Creating a ticket is not starting work on it: when asked only for a ticket, file it, print its URL and stop.

A prompt that is only the URL of an issue in this repository, `https://github.com/<owner>/<repo>/issues/<N>` where `<owner>/<repo>` is what `bin/repo` prints, means `/work <N>`: start that flow, do not just summarise the issue. Orca starts an issue workspace's agent with that URL. Agents without a `/work` command read `.claude/skills/work/SKILL.md` and follow it with `<N>` as the argument.

### Vocabulary

- **Issue** — the problem and why it matters. Lives in GitHub. May never produce code.
- **Change** — one review-sized solution: `openspec/changes/<issue>-<6-hex>-<slug>/` with `design.md`, `proposal.md`, delta specs and `tasks.md`. An issue's changes share one branch and one PR; the branch is named after the first change. Types: `feature` (has spec deltas) and `technical` (refactor or internal tooling with no observable contract; `skip_specs: true`). Tooling with an observable contract — a hook rejects X, CI blocks Y, `bin/up` prints Z — is a `feature` under the tooling capability that owns it, such as `repo-rules`, `ci`, `dev-sessions` or `spec-coverage`.
- **Plan** — the change's `tasks.md`, written by `superpowers:writing-plans`.

### Does this need a change?

Anything that changes behaviour or intent needs a change. A cosmetic tweak, or a bug where the code is wrong against the spec, is fixed on a plain `<issue>-<slug>` branch; an untracked urgent fix uses `[HOTFIX]`.

### Flow

`/work <issue>` → breakdown (posted) → every change: `bin/openspec-change-id.sh` (+ the branch, for the first change) → `/opsx:new` → `/opsx:continue`: designs of every change (approved), via `superpowers:brainstorming` with their questions in one round → proposal and specs of every change → plans of every change (approved), via `superpowers:writing-plans` → per change: `/opsx:apply` (inline) → prove it on the running stack → after the last change, `/work-pr` (`/opsx:verify` on every change, archive every change as the last commits, followed only by review fixes, one review of the whole branch by a fresh agent via `superpowers:requesting-code-review`, draft PR, CI green, marked ready) → human review and merge.

`/work <issue> --auto` runs the same flow unattended: the agent approves its own breakdown, designs and plans and records each approval on the change and the issue, keeps every mechanical gate, refuses an issue whose author cannot push, escalates what it cannot fix and stops at a ready PR. The `/factory` skill runs it per ready issue.

One issue is one branch and one PR; never split its work into several PRs, or into several issues to get several PRs, unless the user asks. The `/work` skill has the rules.

### Claude Code plugins

`.claude/settings.json` declares the plugins the workflow needs, and `bin/setup` installs them, with Orca's `orca-cli` skill when Orca is present. Restart a running session after `bin/setup` to load what it installed. `claude-plugins` fails when the instructions name a plugin skill that is not declared.

### Routing superpowers output

A superpowers design goes to the `design.md`, and a plan to the `tasks.md`, of the change you are working on, the issue's latest active change on the current branch; never to `docs/superpowers/` (`conventions`).

### OpenSpec CLI

Run it as `bin/openspec` (pinned version, telemetry off), wherever an OpenSpec skill says `openspec ...`. It pins the workflow profile, so `bin/openspec update` regenerates the same skills on every machine.

## Definition of done

You run builds, tests and the stack yourself — do not wait to be asked. A change is done only when every item holds:

1. **Tests first.** Each behaviour was driven by a failing test. Every spec scenario is covered: unit and integration tests in the service, and an end-to-end test whose title cites the scenario ID as `[<id>]`, in `services/e2e/tests/` for anything a user or client sees and in `bin/tests/` for tooling. A scenario no end-to-end test can reach carries a last line `- **NO E2E** <category>: <reason>` in its spec (`spec-coverage`).
2. **Every gate passes locally** for each affected service: lint, typecheck, unit and integration tests, coverage at 100% lines and functions, no duplicated blocks, no unused code and no import-rule breaks (`bin/check`, which runs them with no network). Never edit a test, a `NO E2E` exclusion, a ratchet or a suppression file (`bin/*-disables.txt`), a coverage exclusion, a lint config, or a structure config (`.jscpd.json`, `knip.config.ts`, `.dependency-cruiser.mjs`) to make a check pass: stop and report which check fails and why. Lowering a ratchet after a real fix is the normal flow. A coverage exclusion carries an inline comment saying why. No assertion-free tests; no snapshot-only tests of logic. `services/e2e` has its own lighter gates (its `AGENTS.md`). Do not run mutation testing (`bin/mutate`) while working, not even locally: it takes hours, and runs only in CI's `mutation` workflow, started by hand: `gh workflow run mutation -R "$(bin/repo)"`. A mutant that run reports is killed by a test that fails on it, or, when it cannot change behaviour, marked `// Stryker disable next-line <mutator>: <reason>`. A marked equivalent mutant raises that service's count in `bin/mutation-disables.txt`; removing one lowers it (`mutation-disables`: `bin/check-disables.sh mutations`, which also rejects a marker in any other form).
3. **Proven on the running stack.** Bring up your worktree's stack with `bin/up` (an Orca workspace's stack already watches its sources; elsewhere add `--watch`, run in the background, to rebuild while you edit), run `bin/e2e --changed` while iterating (only the tests of the capabilities the branch changes) and the full `bin/e2e` before handover, and use the change for real: drive a browser for anything a user sees, send real requests for APIs and workers. The browser you drive by hand is the Orca browser, through the `orca-cli` skill, when `orca` is on `PATH`; only without Orca use the Playwright MCP, and no other browser tool. `bin/e2e` is Playwright too and runs either way. For anything a user sees, capture `bin/e2e --proof --change <id> -- --grep "<the change's scenario IDs>"` and commit the screenshots it writes to the change's `proof/` folder (add `--video` for a recording); the PR shows them through `bin/proof-markdown`, and `ui-proof` fails a ready PR that changes `services/ui/src/` without them. When the change is tooling or CI, run the hook, script or check itself and show it rejecting bad input and accepting good input.
4. **Every OpenSpec change of the issue is archived**, one commit each, as the PR's last commits, followed only by review fixes; `change-archived` fails a ready PR while any change of the branch's issue is not archived.
5. **CI is green.** Only then mark the PR ready and hand it to a human.

## Safety

- Never push to `main`, and never merge a PR. A human merges. The one exception is automatic mode: the `/factory` coordinator merges a PR through `bin/factory-merge` once every check is green; its `/work <issue> --auto` workers never merge. The pre-push hook refuses pushes to `main`; a human pushing on purpose sets `FACTORY_PUSH_PROTECTED=1`.
- Never force-push. When `main` moves, merge it into the branch. Rewriting commits already pushed, such as a subject CI rejects, is a human's call: stop and ask. The pre-push hook refuses force-pushes.
- No secrets in the repository. Never print, log or commit a secret value.
- A new dependency needs a reason in the change's design. Prefer mainstream, well-known packages. Check the exact package name exists and is the one you mean.

## Improving these rules

When you are corrected on the same thing twice, propose a mechanical guard — a lint rule, test, type or CI check — as an issue. Add a line here only when nothing mechanical can enforce it.

## Commit messages

`[12][a3f9c1] api: Reject expired tokens`: the issue number, the change branch's 6-hex hash, a lowercase scope when the commit touches one service, then an imperative, sentence-case subject of at most 72 characters; `[12] ...` on an issue branch (`12-<slug>`), `[HOTFIX] ...` for an untracked urgent fix. The prepare-commit-msg hook writes the prefix; the commit-msg hook and CI's `commit-subjects` reject the rest.

The body is optional; when present it explains *why*.

## Pull requests

The title and the Summary, Changes and Proof sections are checked on every PR, drafts included (`pr-body`). Title: the commits' prefix, then a comprehensive description: `[12][a3f9c1] Allocate isolated session slots per worktree`. The body is plain markdown, no shell constructs, with `## Summary` (what and why, `Closes #<issue>`, and one ``Change: `<change-id>` `` line per change), `## Changes` (with a `### Specs` subsection listing capability deltas), `## Proof` (screenshots, a recording, or excerpts from the running stack) and `## Review` (every finding of the agent review and of `/opsx:verify`, each fixed or deferred with a reason, or `No findings.`; `review-section`).

## Commands

| Command | What it does |
|---|---|
| `bin/setup` | Prepare a clone or worktree: the git hooks, a local `.env` and the Claude Code plugins; safe to run again |
| `bin/setup-env.sh` | Write `.env` from `.env.example` with random dev values, keeping existing ones; usage in `--help` |
| `bin/doctor` | Check the machine (Docker, Compose, `gh` login, Orca, Claude Code, WSL) and print a fix for each problem |
| `bin/up [--watch]` | Start this worktree's stack in its own session slot, wait until healthy, print its URLs |
| `bin/stop` | Stop the stack, keeping its data and slot |
| `bin/down` | Remove the stack and its data, and free the slot |
| `bin/seed` | Create the demo user on this worktree's stack; `bin/up` runs it; usage in `--help` |
| `bin/logs [service] [flags]` | Show the stack's logs; flags pass through to Compose |
| `bin/compose <args>` | Docker Compose against this worktree's stack |
| `bin/e2e [--changed \| --gates \| --proof [--change <id>] [--video]] [-- <playwright args>]` | Run the `services/e2e` suite against this worktree's stack; `--changed` runs only the tests of the capabilities the branch changes; `--gates` lints and typechecks it; `--proof` saves a screenshot per test (and a video with `--video`) into the change's `proof/` folder; usage in `--help` |
| `bin/proof-markdown <ref>` | Print the PR's `## Proof` section from the committed proof files; usage in `--help` |
| `bin/session <command>` | The slot registry: claim, list, ports, reap, watch; usage in `--help` |
| `bin/orca-setup` | Orca's setup hook: bin/setup, bin/up, a background watch, the UI tab; usage in `--help` |
| `bin/orca-archive` | Orca's archive hook: bin/down of the workspace; usage in `--help` |
| `bin/orca-autostart` | Submit an Orca issue workspace's pre-filled issue URL; usage in `--help` |
| `bin/repo` | Print `<owner>/<repo>` of the `origin` remote; usage in `--help` |
| `bin/issue-trust <issue> [--comments]` | Exit 0 when the issue's author can push to the repository, 4 when not; `--comments` lists commenters who cannot; usage in `--help` |
| `bin/factory-graph <label> [--json]` | List a label's open issues as ready, blocked, untrusted, taken or cycle, from their `after:` lines; usage in `--help` |
| `bin/factory-merge <pr>` | Merge a ready PR only when every check is green; the `/factory` coordinator's only way to merge; usage in `--help` |
| `bin/tests/run.sh [<name>]` | Run the repo script tests in `bin/tests/` |
| `bin/check-conventions.sh` | Fail on the writing conventions above; rules in `--help` |
| `bin/check-home-paths.sh [--staged \| -]` | Fail on paths into one person's home directory; usage in `--help` |
| `bin/check-lint-disables.sh` | Fail when a service's lint suppressions differ from `bin/lint-disables.txt`; usage in `--help` |
| `bin/mutate <service> [--changed [--base <ref>]]` | Mutation-test a service in its `mutate` container and keep the reports under `tmp/mutate/<service>/`; run only by CI's `mutation` workflow, started by hand, never while working; usage in `--help` |
| `bin/check-disables.sh <kind>` | Fail when a service's marked exceptions of one kind differ from that kind's baseline, such as `bin/duplicate-disables.txt`; kinds and usage in `--help` |
| `bin/check-image-digests.sh` | Fail on a Docker image reference not pinned as `<name>:<tag>@sha256:<digest>`; how to bump an image in `--help` |
| `bin/check-eof-newline.sh [--staged] <path>...` | Fail on a text file without a final newline |
| `bin/ci-secret-scan.sh <base> <head>` | CI's secret-scan step: scan the commits of a range for secrets, every commit up to `<head>` without a base; usage in `--help` |
| `bin/audit [<service>...]` | CI's dependency-audit step: audit each service's locked dependencies, failing on a critical advisory; usage in `--help` |
| `bin/ci-eof-newline.sh <base> <head>` | CI's eof-newline step: the newline check over the files a range changed, or every tracked file without a base; usage in `--help` |
| `bin/check-commit-subject.sh <branch> <subject>` | Check one commit subject against "Commit messages" |
| `bin/check-commit-range.sh <branch> <base> <head>` | Check every commit subject in a range, as CI does |
| `bin/ci-review-section.sh <pr-number>` | CI's review-section check: fail a ready PR without a `## Review` section |
| `bin/ci-pr-body.sh <pr-number>` | CI's pr-body check: fail a PR whose title or body breaks "Pull requests"; usage in `--help` |
| `bin/ci-ui-proof.sh <pr-number>` | CI's ui-proof check: fail a ready PR that changes `services/ui/src/` without an image or video in `## Proof` |
