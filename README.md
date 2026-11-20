# Software factory template

A starter web application that grows into a small CRM one GitHub issue at a
time, built the agent-native way: AI agents write, test and prove the code,
and humans set direction and approve. Use it to build something, or study it
to see how a repository can be shaped so that agents do reliable work in it.

## The idea

Agents are fast and tireless, but they forget, guess and drift. This template
answers that with structure rather than hope:

- **Humans decide at four gates:** the issue breakdown, the design, the plan
  and the merge. Everything between the gates runs from the command line,
  unattended.
- **Specs are the source of truth.** Every behaviour lives in
  [openspec/specs/](openspec/specs/) as requirements with scenarios. Each
  scenario has a stable ID, and an end-to-end test cites it.
- **Rules are encoded, not exhorted.** Git hooks and CI checks enforce
  coverage, commit format, spec coverage, pinned images and more. A rule
  only stays prose in [AGENTS.md](AGENTS.md) when nothing mechanical can
  enforce it.
- **Work is proven on a running system.** Every worktree gets its own stack.
  An agent brings it up, uses the change for real and attaches the evidence
  to the pull request.

The reasons behind each rule are in [docs/principles.md](docs/principles.md);
what is being built is in [docs/product.md](docs/product.md).

## How a change flows

```
GitHub issue
  → breakdown into OpenSpec changes        (posted on the issue)
  → design of every change                 (you approve)
  → spec deltas and a plan per change      (you approve the plans)
  → tests first, then code, per change
  → proof on the worktree's own stack      (bin/up, bin/e2e)
  → archive the changes into the specs
  → review by a fresh agent, draft PR, CI green
  → ready for review                       (you merge)
```

In Claude Code, `/work <issue>` runs this whole flow and `/work-pr` its last
part. Each step is a skill under [.claude/skills/](.claude/skills/) that you
can read.

## Installation

### 1. Install the tools

| Tool | Why | Where |
|---|---|---|
| git | everything | your package manager |
| Docker with Compose 2.22 or newer | every stack, check and test runs in containers | [Docker Desktop](https://docs.docker.com/get-docker/) on macOS and Windows; Docker Engine and the Compose plugin on Linux |
| GitHub CLI (`gh`) | issues, pull requests and CI from the command line | [cli.github.com](https://cli.github.com/), then `gh auth login` |
| Node.js 24 or newer | runs the pinned OpenSpec CLI | [nodejs.org](https://nodejs.org/) |
| Claude Code | the agent that does the work | [Claude Code setup](https://docs.claude.com/en/docs/claude-code/setup), then sign in |
| `ss` or `lsof` | finding free ports for each stack | preinstalled on macOS and most Linux distributions |
| Orca (optional) | one workspace, stack and browser tab per issue | `bin/orca-setup --help` explains the integration |

**Windows:** work inside WSL 2 with Docker Desktop's WSL integration on, and
keep the clone in the Linux file system (for example `~/code`), never under
`/mnt/c/`: bind mounts there are slow and lose executable bits.

### 2. Create your repository

On GitHub, choose **Use this template** to create your own repository, then
clone it:

```
git clone <your repository's URL>
cd <your repository>
```

Every command below runs from the root of the clone.

### 3. Check the machine

```
bin/doctor
```

It prints one line per check, marked `ok`, `warn` or `FAIL`, with a `fix:`
line under each problem. Fix every `FAIL` and run it again until it exits
cleanly.

### 4. Set up the clone

```
bin/setup
```

This installs the git hooks, writes a local `.env` with random development
values (never committed), and installs the Claude Code plugins the workflow
needs. Restart any running Claude Code session afterwards so it loads them.
It is safe to run again.

### 5. Start the stack

```
bin/up
```

It builds and starts Postgres, the backend and the UI in this clone's own
slot, waits until they are healthy, creates the demo user and prints the
URLs. Open the UI URL and sign in as `demo@example.com` with the password
`password`. `bin/e2e` then runs the end-to-end suite against it.

| Command | What it does |
|---|---|
| `bin/logs [service]` | the stack's logs |
| `bin/stop` | stop the stack, keeping its data |
| `bin/down` | remove the stack, its data and its slot |

### 6. Protect main (recommended)

CI runs on GitHub-hosted runners with no setup. In the repository's
settings, protect `main` and require the checks of
[.github/workflows/checks.yml](.github/workflows/checks.yml) so that nothing
merges red. Agents never push to `main`; the pre-push hook already refuses it.

## Your first issue

1. File work as GitHub issues: `/ticket` in Claude Code writes one, or
   `/crm-backlog` files the whole CRM backlog of small, ordered issues.
2. Start Claude Code in the clone and run `/work <issue number>`.
3. Answer the questions it asks in one round, then approve the designs and
   then the plans.
4. It writes the tests first, then the code, proves the change on the stack,
   archives the changes, has a fresh agent review the branch and opens a
   pull request with the proof and the review's findings.
5. When CI is green and the pull request is marked ready, review it and
   merge it yourself.

The rules every agent follows, and every command with its flags, are in
[AGENTS.md](AGENTS.md); each command also explains itself with `--help`.

## Build the CRM

The CRM grows from a backlog of small, ordered issues. Build the first ones
yourself to see every gate, then let the factory build the rest.

1. **File the backlog.** In Claude Code, `/crm-backlog --dry-run` lists the
   issues it would file and what each one depends on; `/crm-backlog` files
   them, labelled `crm`, each with an `after:` line for every issue it needs
   first. Running it again skips what already exists.
2. **Build one or two by hand.** Pick an issue with no `after:` line and run
   `/work <issue number>`, or start an Orca workspace from the issue's URL.
   Answer its questions, approve the design and the plan, then review and
   merge the pull request yourself.
3. **Hand the rest to the factory.** Run `/factory crm`. It starts a
   `/work <issue number> --auto` worker for each issue whose dependencies
   are merged, each in its own Orca workspace and stack, up to your slot
   limit (`FACTORY_SESSION_SLOTS`, default 3). Workers run on Sonnet and
   decide at the gates themselves; every check still applies. The factory
   merges each pull request once every check is green, starts the issues it
   unblocked and prints a status table as it goes. An issue that stays red
   or that a worker escalates is left for you, with its workspace and the
   reason.

Before step 3, `bin/doctor` must show Orca installed and Claude Code's auto
permission mode `ok`: nobody is there to answer a permission prompt. Several
workers at once also use your Claude plan and your GitHub Actions minutes
faster than one session does.

## Repository map

| Path | What lives there |
|---|---|
| [services/backend/](services/backend/) | GraphQL API on Bun and Postgres, with its own checks and [AGENTS.md](services/backend/AGENTS.md) |
| [services/ui/](services/ui/) | the web UI, with its own checks and [AGENTS.md](services/ui/AGENTS.md) |
| [services/e2e/](services/e2e/) | black-box Playwright tests against a running stack |
| [openspec/specs/](openspec/specs/) | how the system behaves today, one folder per capability |
| [openspec/changes/](openspec/) | changes in flight, and every merged one under `archive/` |
| [bin/](bin/) | every command and check, with their tests in [bin/tests/](bin/tests/) |
| [.githooks/](.githooks/) | the hooks `bin/setup` enables |
| [.claude/skills/](.claude/skills/) | the workflow skills: `/work`, `/work-pr`, `/ticket` and more |
| [.github/workflows/](.github/workflows/) | CI: repository checks, service gates, stack proofs, end-to-end tests |

## Study guide

To learn the approach rather than only use it, read in this order:

1. [docs/principles.md](docs/principles.md): why the repository works the
   way it does.
2. [docs/product.md](docs/product.md): what is being built, and for whom.
3. [AGENTS.md](AGENTS.md): the same principles turned into concrete rules
   and commands.
4. [openspec/specs/auth/spec.md](openspec/specs/auth/spec.md): what a living
   spec looks like, with requirements and scenario IDs.
5. [services/e2e/tests/auth.spec.ts](services/e2e/tests/auth.spec.ts): the
   end-to-end tests that cite those scenario IDs.
6. [.claude/skills/work/SKILL.md](.claude/skills/work/SKILL.md): the
   workflow an agent follows for every issue.
7. [services/backend/AGENTS.md](services/backend/AGENTS.md): how one service
   is shaped, so every service looks the same from outside.
8. [.github/workflows/checks.yml](.github/workflows/checks.yml): every rule
   CI enforces.

Then run `/work` on a small issue and watch each gate happen.

## Licence

MIT, see [LICENSE](LICENSE). To report a vulnerability, see
[SECURITY.md](SECURITY.md).
