# agent-workflow Specification

## Purpose
The workflow agents follow from issue to pull request: tickets, claiming an issue, the work and PR flows, and the Claude Code plugins and setup they need.

## Requirements

### Requirement: Claude Code plugins are declared
The repository SHALL declare the Claude Code plugins its workflow requires, and nothing else, one plugin per line in a committed `.claude/settings.json`: `superpowers`, `playwright` and `frontend-design` enabled from the `claude-plugins-official` marketplace.

#### Scenario: [agent-workflow-99ba94] Required plugins are enabled for the project
- **WHEN** a clone's `.claude/settings.json` is read
- **THEN** it enables `superpowers@claude-plugins-official`, `playwright@claude-plugins-official` and `frontend-design@claude-plugins-official`
- **AND** it declares no marketplace of its own

### Requirement: Workflow skills name declared plugins
`bin/check-claude-plugins.sh` SHALL fail, naming the file, line and reference, when an `AGENTS.md`, the OpenSpec schema or a hand-written repository skill names a plugin skill as `` `<plugin>:<skill>` `` or `**<plugin>:<skill>**` whose plugin `.claude/settings.json` does not enable, except for a token that is a script name in a service's `package.json`.

#### Scenario: [agent-workflow-e0c58f] Undeclared plugin skill fails the check
- **WHEN** an `AGENTS.md` names `` `reviewer:deep-review` `` and `.claude/settings.json` enables no `reviewer` plugin
- **THEN** `bin/check-claude-plugins.sh` exits non-zero and prints the file, line and `reviewer:deep-review`

#### Scenario: [agent-workflow-d0a2c7] Declared plugin skills pass the check
- **WHEN** the workflow's instructions name only skills of plugins `.claude/settings.json` enables, as the repository does
- **THEN** `bin/check-claude-plugins.sh` exits 0

#### Scenario: [agent-workflow-ae1460] Package scripts are not skills
- **WHEN** a service `AGENTS.md` names `` `test:unit` `` and that service's `package.json` defines a `test:unit` script
- **THEN** `bin/check-claude-plugins.sh` does not report it

### Requirement: Setup checks the plugins' host binaries
`bin/setup-claude-plugins.sh` SHALL exit non-zero, without installing it itself, when a binary a declared plugin needs is not on `PATH`, printing the binary, the plugin and the command that installs it. Today `playwright` needs `npx`.

#### Scenario: [agent-workflow-3a769a] Missing host binary fails with the fix
- **WHEN** `bin/setup-claude-plugins.sh` runs with `claude` on `PATH` and no `npx`
- **THEN** it exits non-zero and prints `npx`, `playwright` and how to install Node.js

### Requirement: Setup warns about duplicate plugins
`bin/setup-claude-plugins.sh` SHALL warn, without failing, when a declared plugin is also enabled from another marketplace, printing the command that disables the other copy.

#### Scenario: [agent-workflow-f0ecca] A plugin from another marketplace is reported
- **WHEN** Claude Code lists `superpowers@superpowers-marketplace` as enabled
- **THEN** `bin/setup-claude-plugins.sh` warns that `superpowers` loads twice, prints `claude plugin disable superpowers@superpowers-marketplace`, and exits 0

### Requirement: Plugin commands describe themselves
`bin/setup-claude-plugins.sh` and `bin/check-claude-plugins.sh` SHALL print their usage with `--help`, without `claude` or `orca` on `PATH`.

#### Scenario: [agent-workflow-5e93fb] Plugin help needs nothing
- **WHEN** either command runs with `--help` and neither `claude` nor `orca` is on `PATH`
- **THEN** it exits 0 and prints its usage

### Requirement: The work flow runs every change of an issue on one branch
The `/work` skill SHALL record a breakdown as a plain `## Changes` list with no stack or parallel choice and run every change on one branch: the first change creates the branch from `main`, and each later change gets a new change ID, is created on that same branch and starts as soon as the previous change is proven, with no PR or review in between.

#### Scenario: [agent-workflow-604d98] The work skill keeps every change on one branch
- **WHEN** `.claude/skills/work/SKILL.md` is read
- **THEN** it says the breakdown is a plain `## Changes` list, that each later change is created on the same branch with `bin/openspec-change-id.sh` and `/opsx:new`, and that `/work-pr` runs once after the last change
- **AND** it does not mention `gh stack`, a stack or parallel PRs

### Requirement: The PR flow archives every change and opens one PR
The `/work-pr` skill SHALL archive every active change of the branch's issue, one archive commit each, at the end of the branch, and open one draft PR that says `Closes #<issue>` and names every change.

#### Scenario: [agent-workflow-4cb236] The PR skill archives every change into one PR
- **WHEN** `.claude/skills/work-pr/SKILL.md` is read
- **THEN** it says every active `openspec/changes/<issue>-*` change is archived in its own commit, and that the one PR says `Closes #<issue>` and lists every change ID
- **AND** it does not mention `gh stack`

### Requirement: The PR flow re-runs a failed job locally before pushing its fix
When CI fails, the `/work-pr` skill SHALL have the agent read every failed job of the run, fix them all, re-run each failed job's own command from `.github/workflows/checks.yml` locally, and push only once they pass, even while a run is in progress, naming in the hand-over a job whose command cannot run locally.

#### Scenario: [agent-workflow-9e4533] The PR skill re-runs the failed jobs before pushing a fix
- **WHEN** `.claude/skills/work-pr/SKILL.md` is read for how to handle a failed CI run
- **THEN** it says to read every failed job, fix them all, re-run each failed job's command from `.github/workflows/checks.yml` locally and push only once they pass
- **AND** it says a push while a run is in progress cancels the stale run, and that a job that cannot run locally is named in the hand-over

### Requirement: Starting work never takes an issue over silently
On a taken issue `bin/issue-start` SHALL print who holds it and exit 3 without changing the issue, unless `--take-over` is given, which claims it as for a free issue. An issue is taken when it is labelled `in progress` and assigned to anyone but the caller, or assigned to anyone who is neither the caller nor its author.

#### Scenario: [agent-workflow-f43ecb] An issue in progress elsewhere is refused
- **WHEN** `bin/issue-start` runs without `--take-over` on an issue labelled `in progress` and assigned to someone else
- **THEN** it names that assignee, exits 3 and makes no edit to the issue

#### Scenario: [agent-workflow-b22bf2] An issue assigned to a third person is refused
- **WHEN** `bin/issue-start` runs without `--take-over` on an issue without the `in progress` label, assigned to someone who is neither the caller nor its author
- **THEN** it names that assignee, exits 3 and makes no edit to the issue

#### Scenario: [agent-workflow-dbe4d3] Taking over replaces the holder
- **WHEN** `bin/issue-start --take-over` runs on a taken issue
- **THEN** the caller becomes its only assignee, it keeps the `in progress` label and the command exits 0

### Requirement: The work skill starts by claiming the issue
The `/work` skill SHALL run `bin/issue-start <N>` after reading the issue and before breaking it down, asking the user whether to take a taken issue over (rerunning with `--take-over` on yes, stopping on no), and record the starter as the first line of the `## Changes` comment, `Started by @<login> on branch \`<branch>\``, which a resumed `/work` updates instead of posting another comment.

#### Scenario: [agent-workflow-3befd9] The work skill claims the issue and records the starter
- **WHEN** `.claude/skills/work/SKILL.md` is read
- **THEN** it runs `bin/issue-start <N>` before the breakdown, asks before rerunning with `--take-over`, and puts a `Started by @<login> on branch` line at the top of the `## Changes` comment that a resumed run updates

### Requirement: Closing an issue clears its in-progress label
When an issue in `"$(bin/repo)"` closes, CI SHALL remove its `in progress` label, leaving an issue without the label unchanged and passing.

#### Scenario: [agent-workflow-1f6fa7] A closed issue loses the label
- **WHEN** `bin/ci-issue-closed.sh <N>` runs for a closed issue labelled `in progress`
- **THEN** it removes the label and exits 0

#### Scenario: [agent-workflow-bfbf53] A closed issue without the label passes
- **WHEN** `bin/ci-issue-closed.sh <N>` runs for a closed issue without the `in progress` label
- **THEN** it makes no edit and exits 0

### Requirement: Setup installs each missing declared plugin
`bin/setup-claude-plugins.sh` SHALL install, at project scope, each plugin `.claude/settings.json` enables that Claude Code does not list as installed, leaving `.claude/settings.json` unchanged.

#### Scenario: [agent-workflow-8c99e3] Missing plugins are installed
- **WHEN** `bin/setup-claude-plugins.sh` runs and Claude Code lists `superpowers@claude-plugins-official` as installed but not the other two official plugins
- **THEN** it installs `playwright@claude-plugins-official` and `frontend-design@claude-plugins-official` at project scope, installs nothing else, exits 0 and leaves `.claude/settings.json` unchanged

#### Scenario: [agent-workflow-9bbfb8] A second run installs nothing
- **WHEN** `bin/setup-claude-plugins.sh` runs and every declared plugin is installed
- **THEN** it installs nothing and exits 0

### Requirement: A failed plugin install fails setup
When installing a declared plugin fails, `bin/setup-claude-plugins.sh` SHALL exit non-zero naming the plugin.

#### Scenario: [agent-workflow-3cc03d] A failed install fails setup
- **WHEN** installing a declared plugin fails
- **THEN** `bin/setup-claude-plugins.sh` exits non-zero and names that plugin

### Requirement: Setup skips the plugins without Claude Code
When `claude` is not on `PATH`, `bin/setup-claude-plugins.sh` SHALL skip the plugins and say so.

#### Scenario: [agent-workflow-f249f7] No Claude Code skips the plugins
- **WHEN** `bin/setup-claude-plugins.sh` runs without `claude` on `PATH`
- **THEN** it says it skips the Claude Code plugins and exits 0

### Requirement: Setup installs Orca's skill when Orca lacks it
`bin/setup-claude-plugins.sh` SHALL install Orca's `orca-cli` skill through `orca skills install --skill orca-cli` when `orca` is on `PATH` and does not list `orca-cli` as installed.

#### Scenario: [agent-workflow-17906d] orca-cli is installed when Orca lacks it
- **WHEN** `bin/setup-claude-plugins.sh` runs with `orca` on `PATH` and `orca-cli` not installed
- **THEN** it runs `orca skills install --skill orca-cli` and exits 0

#### Scenario: [agent-workflow-7665e4] Installed orca-cli is left alone
- **WHEN** `orca` lists `orca-cli` as installed
- **THEN** `bin/setup-claude-plugins.sh` does not install it again

### Requirement: Setup skips Orca's skill silently without Orca
`bin/setup-claude-plugins.sh` SHALL skip Orca's `orca-cli` skill silently when `orca` is not on `PATH`.

#### Scenario: [agent-workflow-f136ea] No Orca, no orca-cli
- **WHEN** `bin/setup-claude-plugins.sh` runs without `orca` on `PATH`
- **THEN** it does not mention `orca-cli` and exits 0

### Requirement: A failed Orca skill install only warns
A failed install of Orca's `orca-cli` skill SHALL make `bin/setup-claude-plugins.sh` warn without failing.

#### Scenario: [agent-workflow-b5d608] A failed orca-cli install only warns
- **WHEN** `orca skills install --skill orca-cli` fails
- **THEN** `bin/setup-claude-plugins.sh` warns that `orca-cli` is not installed and exits 0

### Requirement: bin/issue-start claims a free issue
`bin/issue-start <N>` SHALL make the caller the only assignee of issue N and label it `in progress`, creating that label in the repository when it is missing, and print `Started by @<login>`.

#### Scenario: [agent-workflow-57ec06] A free issue is claimed
- **WHEN** `bin/issue-start` runs on an issue that is not labelled `in progress` and is unassigned or assigned only to its author
- **THEN** it removes every other assignee, assigns the caller, adds the `in progress` label, prints `Started by @<login>` and exits 0

#### Scenario: [agent-workflow-0928ea] The missing label is created
- **WHEN** `bin/issue-start` claims an issue and the repository has no `in progress` label
- **THEN** it creates the label before adding it to the issue

### Requirement: Resuming one's own issue changes nothing
Run again on an issue the caller already holds, `bin/issue-start` SHALL succeed without asking or changing anything that is already right.

#### Scenario: [agent-workflow-fa3504] Resuming one's own issue changes nothing
- **WHEN** `bin/issue-start` runs on an issue labelled `in progress` and assigned only to the caller
- **THEN** it exits 0, prints `Started by @<login>` and makes no edit to the issue

### Requirement: The issue-closed job uses only the workflow's token
The CI job that clears a closed issue's `in progress` label SHALL use only the workflow's own token, with `issues: write`.

#### Scenario: [agent-workflow-c6112b] The issue-closed job holds only issues write
- **WHEN** `.github/workflows/issues.yml` is read
- **THEN** its `issue-closed` job is granted `issues: write` and passes only `github.token` to `bin/ci-issue-closed.sh`

### Requirement: The PR flow verifies every change before archiving it
The `/work-pr` skill SHALL run `/opsx:verify` on every active change of the branch's issue before archiving it, and have every CRITICAL issue fixed test-first before that change is archived.

#### Scenario: [agent-workflow-26e0f8] The PR skill verifies each change before archiving
- **WHEN** `.claude/skills/work-pr/SKILL.md` is read for how changes are archived
- **THEN** it says to run `/opsx:verify <change-id>` on every change before `bin/openspec-archive`, and to fix every CRITICAL issue test-first first

### Requirement: The PR flow has the branch reviewed independently before the PR opens
After archiving and before the draft PR, the `/work-pr` skill SHALL have a fresh reviewer, not the implementer, review `origin/main..HEAD` once with `superpowers:requesting-code-review`, on the most capable model the agent offers, given the diff, designs, specs and AGENTS.md but not the implementer's conclusions.

#### Scenario: [agent-workflow-901f28] The PR skill dispatches one fresh reviewer on the whole branch
- **WHEN** `.claude/skills/work-pr/SKILL.md` is read for the review step
- **THEN** it says the review runs once, after archiving and before the draft PR, on `origin/main..HEAD`, through `superpowers:requesting-code-review`
- **AND** it says the reviewer runs on the most capable model the agent offers, and is not given the implementer's conclusions

#### Scenario: [agent-workflow-d6c988] An agent without subagents starts a fresh session to review
- **WHEN** `.claude/skills/work-pr/SKILL.md` is read by an agent that cannot dispatch a subagent
- **THEN** it says to start a fresh non-interactive session of the agent's own CLI, read-only, with the same reviewer prompt, and to stop and ask the human when no such session can be started

### Requirement: Serious review findings are fixed before the PR opens
The `/work-pr` skill SHALL have every Critical and Important review finding fixed test-first, in commits on top of the archives, before the draft PR opens.

#### Scenario: [agent-workflow-3f3fda] The PR skill fixes serious findings test-first
- **WHEN** `.claude/skills/work-pr/SKILL.md` is read for what happens to review findings
- **THEN** it says every Critical and Important finding is fixed test-first before the draft PR opens

### Requirement: The PR records every review finding and its outcome
The `/work-pr` skill SHALL list every review finding and every verify warning or suggestion in a `## Review` section of the PR body with its outcome, fixed or deferred with a reason, and `No findings.` for a clean review.

#### Scenario: [agent-workflow-6f3964] The PR body carries a Review section
- **WHEN** `.claude/skills/work-pr/SKILL.md` is read for the PR body
- **THEN** its template has a `## Review` section, and it says every finding is listed as fixed or deferred with a reason, or `No findings.` when there are none

### Requirement: bin/openspec needs Node 24
`bin/openspec` SHALL exit 1 before running the CLI when Node's major version is below 24, printing the version found and how to install Node 24.

#### Scenario: [agent-workflow-3015b0] An old Node is refused with the fix
- **WHEN** `bin/openspec --version` runs with `node --version` printing `v18.19.0`
- **THEN** it exits 1, prints `v18.19.0` and `Node 24`, and does not run npx

### Requirement: bin/openspec never advises another workflow profile
`bin/openspec update` SHALL drop the CLI's note that the custom profile lacks core workflows, passing every other line and the CLI's exit status through.

#### Scenario: [agent-workflow-eea1e6] The profile note is hidden
- **WHEN** the CLI prints the note about missing core workflows and another line, and exits 0
- **THEN** `bin/openspec update` prints only the other line and exits 0

### Requirement: A concurrently created label does not fail a claim
`bin/issue-start` SHALL claim the issue when creating the `in progress` label fails because the label now exists.

#### Scenario: [agent-workflow-da1b1f] The label appears between listing and creating
- **WHEN** the repository has no `in progress` label when listed, and `gh label create` fails because another claim created it meanwhile
- **THEN** `bin/issue-start` assigns the caller, adds the label, prints `Started by @<login>` and exits 0

### Requirement: The CRM backlog files every issue with the crm label
`bin/crm-backlog` SHALL file each issue file of `.claude/skills/crm-backlog/issues/`, in file-name order, into the repository `bin/repo` prints, with the file's title, its body and the `crm` label, creating that label when the repository lacks it, and print `filed #<number> <title>` for each.

#### Scenario: [agent-workflow-74af2b] An empty repository gets the whole backlog
- **WHEN** `bin/crm-backlog` runs against a repository with no issues and no `crm` label
- **THEN** it creates the `crm` label, files one issue per issue file in file-name order, each labelled `crm`, prints `filed #<number> <title>` for each and exits 0

#### Scenario: [agent-workflow-a24e73] A concurrently created label does not fail the run
- **WHEN** the repository has no `crm` label when listed, and creating it fails because another run created it meanwhile
- **THEN** `bin/crm-backlog` files every issue and exits 0

### Requirement: The CRM backlog states dependencies as issue numbers
`bin/crm-backlog` SHALL write each `after: <file>` line of an issue file as `after: #<number>`, the number of the issue filed or found for that file.

#### Scenario: [agent-workflow-ae4bb4] Dependencies point at the filed issues
- **WHEN** an issue file has `after: 01-contacts-list` and that file was filed as issue 41
- **THEN** the issue filed from it has the line `after: #41`

### Requirement: Filing the CRM backlog again is safe
`bin/crm-backlog` SHALL skip an issue file whose title is already the title of an open or closed issue, print `exists #<number> <title>`, reuse an existing `crm` label, and still resolve dependencies on the skipped issue to its number.

#### Scenario: [agent-workflow-5f2d29] Existing titles are skipped
- **WHEN** `bin/crm-backlog` runs against a repository that already has a closed issue 7 titled like the first issue file and the `crm` label
- **THEN** it does not file that issue or create the label, prints `exists #7 <title>`, files the rest, and writes `after: #7` for the issues that depend on it

### Requirement: The CRM backlog never lands in a template repository
`bin/crm-backlog` SHALL exit 1 without creating a label or an issue when the repository is a GitHub template, saying the backlog belongs in a copy of the template, or when it cannot read whether the repository is one.

#### Scenario: [agent-workflow-6784a0] A template repository is refused
- **WHEN** `bin/crm-backlog` runs and the repository is marked as a template
- **THEN** it exits 1, prints that the repository is a template, and creates no label and no issue

### Requirement: A dry run of the CRM backlog writes nothing
`bin/crm-backlog --dry-run` SHALL make only reads, printing `would create label crm` when the label is missing, `would file <title>` or `exists #<number> <title>` for each issue file and, under each issue it would file, its dependencies as `after: <title>`.

#### Scenario: [agent-workflow-dcdfc6] The dry run only reads
- **WHEN** `bin/crm-backlog --dry-run` runs against a repository with one existing backlog title
- **THEN** it prints `would create label crm`, `exists #<number> <title>` for that one, `would file <title>` with its `after:` titles for every other, creates no label and no issue, and exits 0

### Requirement: A malformed CRM issue file stops the run before writing
`bin/crm-backlog` SHALL exit 1, naming the file, before creating a label or an issue, when an issue file is not named `<NN>-<slug>.md`, has no `# <title>` first line, no body, or an `after:` line that is not `after: <file>` naming an earlier issue file.

#### Scenario: [agent-workflow-4be6a3] A forward dependency is refused
- **WHEN** an issue file has `after:` naming a file that sorts after it
- **THEN** `bin/crm-backlog` exits 1, names the file, and creates no label and no issue

### Requirement: The CRM backlog is a set of small tickets
The repository SHALL ship between 20 and 30 CRM issue files, each with a unique title and the `/ticket` shape: `## Problem`, `## What we want` and `## Scope`, naming no repository.

#### Scenario: [agent-workflow-322d7f] The issue files are tickets
- **WHEN** the issue files under `.claude/skills/crm-backlog/issues/` are read
- **THEN** there are 20 to 30, their titles are unique, each has `## Problem`, `## What we want` and `## Scope`, and none names a repository

### Requirement: The CRM backlog skill files and stops
The `/crm-backlog` skill SHALL run `bin/crm-backlog`, print what it filed, and start no work on any issue.

#### Scenario: [agent-workflow-b95246] The skill runs the script and stops
- **WHEN** `.claude/skills/crm-backlog/SKILL.md` is read
- **THEN** it runs `bin/crm-backlog`, offers `--dry-run`, and says filing the backlog is not starting work on it
- **AND** it names no repository

### Requirement: The CRM backlog command describes itself
`bin/crm-backlog --help` SHALL print its usage and exit 0 without calling `gh`.

#### Scenario: [agent-workflow-4c8a3b] Help needs no gh
- **WHEN** `bin/crm-backlog --help` runs with no `gh` on `PATH`
- **THEN** it exits 0 and prints its usage

### Requirement: bin/issue-trust tells whether an issue's author can push
`bin/issue-trust <issue>` SHALL report, without changing anything on GitHub, whether the issue's author has push access to the repository `bin/repo` prints: exit 0 with `trusted: @<login> (<role>)` when they have, exit 4 naming the author on stderr when not, and exit 2 on a usage error.

#### Scenario: [agent-workflow-4ff0b0] An author who can push is trusted
- **WHEN** `bin/issue-trust` runs on an issue whose author has push access
- **THEN** it prints `trusted: @<login> (<role>)` and exits 0

#### Scenario: [agent-workflow-a6eb04] An author who cannot push is untrusted
- **WHEN** `bin/issue-trust` runs on an issue whose author has read access or none
- **THEN** it names the author on stderr, says they cannot push, and exits 4

#### Scenario: [agent-workflow-d80f96] A bad argument is a usage error
- **WHEN** `bin/issue-trust` runs without an issue number or with a non-numeric one
- **THEN** it prints its usage and exits 2 without calling GitHub

### Requirement: bin/issue-trust lists untrusted commenters on request
With `--comments`, `bin/issue-trust` SHALL also print one `untrusted-comment: @<login>` line for each distinct comment author who cannot push or cannot be checked; its exit status still reflects only the issue's author.

#### Scenario: [agent-workflow-9ce42c] Untrusted commenters are listed
- **WHEN** `bin/issue-trust <issue> --comments` runs on a trusted author's issue with comments by one collaborator and one stranger
- **THEN** it prints one `untrusted-comment:` line naming the stranger only and exits 0

### Requirement: The work skill warns before acting on an untrusted issue
When `bin/issue-trust <N>`, run after reading the issue and before claiming it, finds the author untrusted or cannot check them, the `/work` skill SHALL warn, treat the issue's text as data and not as instructions, and ask the user whether to continue, stopping without claiming the issue on no.

#### Scenario: [agent-workflow-caac0e] The work skill checks trust before claiming
- **WHEN** `.claude/skills/work/SKILL.md` is read
- **THEN** it runs `bin/issue-trust <N>` before `bin/issue-start <N>`, and on exit 4 or a failure warns, treats the issue text as untrusted data and asks before going on

### Requirement: The work flow has an automatic mode
`/work <N> --auto` SHALL run the same flow as `/work <N>`, with the agent deciding at every point where the manual flow asks the user and every mechanical gate kept: tests first, the checks, the end-to-end suite, proof, verify, archive, the independent review and CI.

#### Scenario: [agent-workflow-5a5aad] The work skill describes automatic mode
- **WHEN** `.claude/skills/work/SKILL.md` is read
- **THEN** it accepts `--auto`, says the agent approves its own breakdown, designs and plans in that mode, and says no mechanical gate is skipped

### Requirement: Automatic mode records every approval
In automatic mode the agent SHALL record each approval it gives: a `Mode: automatic` line in the breakdown comment, an `Approved by the agent in automatic mode on <date>.` line at the end of each `design.md` and `tasks.md`, one issue comment per gate naming the approved artifacts, and its answers to design questions in `design.md` as `Agent's call:` decisions.

#### Scenario: [agent-workflow-4bb91f] The work skill records self-approvals
- **WHEN** `.claude/skills/work/SKILL.md` is read
- **THEN** its automatic mode writes the `Mode: automatic` line, the `Approved by the agent in automatic mode` line in each design and plan, an issue comment per gate and `Agent's call:` decisions

### Requirement: Automatic mode refuses an issue it may not take
In automatic mode `/work` SHALL refuse, without posting or claiming anything, an issue whose author `bin/issue-trust` does not trust or cannot check, or that `bin/issue-start` reports as taken (never taking it over); comments by authors who cannot push are ignored.

#### Scenario: [agent-workflow-debaf7] Untrusted and taken issues are refused in automatic mode
- **WHEN** `.claude/skills/work/SKILL.md` is read
- **THEN** its automatic mode runs `bin/issue-trust <N> --comments` before reading or claiming the issue, stops with `refused` on exit 4, a failure or `bin/issue-start` exit 3, and never reads a comment by a login listed as `untrusted-comment`

### Requirement: Automatic mode keeps the branch current by merging main
In automatic mode the agent SHALL bring `main` into its branch only by merging it, never by a rebase or a force-push, before pushing for the PR and whenever told `main` moved, then regenerate contracts and rerun the checks.

#### Scenario: [agent-workflow-b160a0] The work skill merges main and never rebases
- **WHEN** `.claude/skills/work/SKILL.md` and `.claude/skills/work-pr/SKILL.md` are read
- **THEN** automatic mode merges `origin/main`, regenerates contracts with `bin/contracts`, reruns `bin/check` and `bin/e2e --changed`, and forbids rebasing and force-pushing

### Requirement: Automatic mode escalates what it cannot fix
In automatic mode the agent SHALL escalate and stop when the same CI check still fails after three fix pushes, when a merge conflict cannot be resolved with both sides' tests green, or when a question can be answered only by a human: it posts an issue comment starting `Escalated:` with what failed and what it tried.

#### Scenario: [agent-workflow-8a3cea] The skills describe escalation
- **WHEN** `.claude/skills/work/SKILL.md` and `.claude/skills/work-pr/SKILL.md` are read
- **THEN** automatic mode posts an `Escalated:` comment and stops after three failed fix pushes of one check, an unresolvable conflict, or a human-only question

### Requirement: The PR flow in automatic mode stops at a ready PR
`/work-pr --auto` SHALL stop after marking the PR ready and report it, never merging it: as an Orca worker through `worker_done`, where an escalation or refusal is a failed `worker_done`.

#### Scenario: [agent-workflow-8955de] The PR skill reports a ready PR in automatic mode
- **WHEN** `.claude/skills/work-pr/SKILL.md` is read
- **THEN** with `--auto` it ends with `ready: <PR URL>`, reported through `worker_done` by an Orca worker, and says the worker never merges

### Requirement: Unattended workers need no permission prompt
`.claude/settings.json` SHALL allow without a prompt the commands the work and PR flows run (file edits in the workspace, `git`, `gh`, `bin/*` with Docker Compose through `bin/compose`, `orca`, read-only shell tools and the browser tools) and no unrestricted `Bash`, while denying force-pushes, rebases (`git pull --rebase` included), pushes to `main`, pushes that skip the git hooks (`--no-verify`, `git -c`), merging a PR (`gh pr merge`, bare or not, and `gh api` merge calls) and `gh repo delete`.

#### Scenario: [agent-workflow-49f622] The settings ship the allowlist and the deny list
- **WHEN** `.claude/settings.json` is read
- **THEN** `permissions.allow` covers `git`, `gh`, `bin/`, `orca` and edits, holds no bare `Bash` entry, and `permissions.deny` holds force-push, rebase and `git pull --rebase`, push to `main`, `--no-verify` and `git -c`, `gh pr merge` and `gh api` merges, and `gh repo delete`

#### Scenario: [agent-workflow-19ade3] A worker runs an issue without a prompt
- **WHEN** a `/work <N> --auto` worker in Claude Code's auto permission mode runs an issue from claim to ready PR in an Orca workspace
- **THEN** it never waits on a permission prompt
- **NO E2E** external: needs a live Claude Code session, a real GitHub repository and real merges, which CI cannot reach; proven by the factory proof run recorded in the PR

### Requirement: bin/doctor checks the permission mode automatic mode needs
When Claude Code is installed, `bin/doctor` SHALL report whether the user's Claude Code settings (`settings.json` under `CLAUDE_CONFIG_DIR`, default `~/.claude`) set `permissions.defaultMode` to `auto`, warning with the setting to add when they do not, without failing the run.

#### Scenario: [agent-workflow-2276f2] Auto mode set is reported ok
- **WHEN** `bin/doctor` runs and the user's Claude Code settings set `permissions.defaultMode` to `auto`
- **THEN** it prints an `ok` line for Claude Code's auto permission mode

#### Scenario: [agent-workflow-d6f086] Auto mode missing only warns
- **WHEN** `bin/doctor` runs and the user's Claude Code settings are missing or set another mode
- **THEN** it prints a `warn` line naming automatic mode with a fix that sets `permissions.defaultMode` to `auto`, and the warning alone does not make it exit 1

### Requirement: Only the coordinator merges, and only in automatic mode
AGENTS.md and `docs/principles.md` SHALL say that a human merges every pull request, except in automatic mode, where the `/factory` coordinator merges one once every check is green, and that a `/work` worker never merges.

#### Scenario: [agent-workflow-f2180f] The rules name the coordinator as the only merging agent
- **WHEN** AGENTS.md → Safety and `docs/principles.md` are read
- **THEN** they name `/factory` as the only agent that merges, only in automatic mode and only once every check is green, and say workers never merge

### Requirement: bin/factory-graph classifies a label's open issues
Without changing anything on GitHub, `bin/factory-graph <label>` SHALL print one line per open issue of the label in the repository `bin/repo` prints, in issue-number order, as `<state> #<n> <title>`, where the state is `ready`, `blocked`, `untrusted`, `taken` or `cycle`; `--json` prints the same records as JSON.

#### Scenario: [agent-workflow-a8456b] An issue without open dependencies is ready
- **WHEN** an open issue of the label has no `after:` line, or only `after:` lines naming closed issues
- **THEN** `bin/factory-graph <label>` prints it as `ready`

#### Scenario: [agent-workflow-e03701] JSON output carries the same records
- **WHEN** `bin/factory-graph <label> --json` runs
- **THEN** it prints a JSON array with each issue's number, title, state and open dependencies

### Requirement: An issue waits for its open dependencies
`bin/factory-graph` SHALL classify an issue as `blocked` while any issue its `after: #<n>` lines name is open, whatever its label, or does not exist, listing those issues, a missing one as `#<n> (missing)`.

#### Scenario: [agent-workflow-4d6cae] An open dependency blocks an issue
- **WHEN** an issue of the label has `after: #a` and `#a` is open
- **THEN** it is printed as `blocked` with `after #a`

#### Scenario: [agent-workflow-dc0884] A missing dependency blocks an issue
- **WHEN** an issue's `after:` line names an issue number that does not exist
- **THEN** it is printed as `blocked` with that number marked `(missing)`

### Requirement: The graph sets aside issues no worker may take
`bin/factory-graph` SHALL classify as `untrusted` an issue whose author `bin/issue-trust` does not trust or cannot check, as `taken` an issue labelled `in progress`, and as `cycle` an issue on a dependency cycle among open issues; these take precedence over `ready` and `blocked`.

#### Scenario: [agent-workflow-55c314] A stranger's issue is untrusted
- **WHEN** an open issue of the label was filed by someone who cannot push
- **THEN** it is printed as `untrusted`

#### Scenario: [agent-workflow-5ce1e6] An issue in progress is taken
- **WHEN** an open issue of the label carries the `in progress` label
- **THEN** it is printed as `taken`

#### Scenario: [agent-workflow-504c59] Issues on a dependency cycle are reported
- **WHEN** two open issues of the label each name the other in an `after:` line
- **THEN** both are printed as `cycle`

### Requirement: bin/factory-merge merges only a green, ready PR
`bin/factory-merge <pr>` SHALL merge the head commit whose checks it read, with a merge commit, deleting its branch, only when the PR is open, not a draft, mergeable, holds every commit of its base branch, and every check has completed with success or was skipped; otherwise it changes nothing, prints the reason (`draft`, `conflicting`, `behind <base>`, `checks pending` or `check failed: <name>`) and exits 3.

#### Scenario: [agent-workflow-792ec5] A green ready PR is merged
- **WHEN** `bin/factory-merge` runs on an open, ready, mergeable PR whose checks all succeeded
- **THEN** it runs `gh pr merge <pr> --merge --delete-branch` against `bin/repo` and exits 0

#### Scenario: [agent-workflow-1ebd00] Only the commit whose checks were read is merged
- **WHEN** `bin/factory-merge` merges a PR
- **THEN** it passes the head commit it read to `gh pr merge --match-head-commit`, so a push after the checks were read refuses the merge

#### Scenario: [agent-workflow-03d810] A PR with a failed check is not merged
- **WHEN** `bin/factory-merge` runs on a PR one of whose checks failed
- **THEN** it prints `check failed: <name>`, exits 3 and does not merge

#### Scenario: [agent-workflow-bbad9e] A draft, conflicting or pending PR is not merged
- **WHEN** `bin/factory-merge` runs on a draft PR, a conflicting PR, or one with a check still running
- **THEN** it prints `draft`, `conflicting` or `checks pending`, exits 3 and does not merge

#### Scenario: [agent-workflow-60965a] A PR behind its base is not merged
- **WHEN** `bin/factory-merge` runs on a green PR whose branch lacks a commit of its base branch, such as another worker's PR merged since its checks ran
- **THEN** it prints `behind <base>`, exits 3 and does not merge

### Requirement: The factory skill coordinates automatic workers
The `/factory <label>` skill SHALL read the graph with `bin/factory-graph`, create an Orca Run with one Task per ready issue and per blocked issue whose every blocker has a Task of the run, with those Tasks as its dependencies, start each Task the graph shows ready's worker in a new Orca workspace created agent-first on Sonnet and bound to the Task, running `/work <N> --auto`, no more at once than the free session slots, and report untrusted, taken and cycle issues as skipped.

#### Scenario: [agent-workflow-e2d3b3] The factory skill starts workers per ready issue
- **WHEN** `.claude/skills/factory/SKILL.md` is read
- **THEN** it runs `bin/factory-graph <label> --json`, creates a Run and Tasks with dependencies, creates each workspace with `orca worktree create --agent claude --model sonnet` before binding it with `orca orchestration worker-start --task`, gives it `/work <N> --auto`, bounds workers by the free slots and reports skipped issues

### Requirement: The factory starts no worker without auto permission mode
The `/factory` skill SHALL run `bin/doctor` before starting any worker and stop, showing the fix, unless it reports Claude Code's auto permission mode as `ok`.

#### Scenario: [agent-workflow-56ada4] The factory skill checks the permission mode first
- **WHEN** `.claude/skills/factory/SKILL.md` is read
- **THEN** it runs `bin/doctor` before the first worker and stops unless the auto permission mode line is `ok`

### Requirement: The factory merges ready PRs and starts what they unblock
On a worker's ready PR the `/factory` skill SHALL merge it through `bin/factory-merge` only, then tell every running worker that `main` moved, remove the merged workspace and start the Tasks that became ready; a merge refused for a conflict, a branch behind `main` or a failed check goes back to its worker.

#### Scenario: [agent-workflow-2bbde1] The factory skill merges through the guard
- **WHEN** `.claude/skills/factory/SKILL.md` is read
- **THEN** it merges only with `bin/factory-merge`, sends `main moved` to running workers after a merge, removes the merged workspace, starts newly ready Tasks, and sends a `conflicting`, `behind main` or failed-check refusal back to the worker

### Requirement: The factory reports escalations and its status
On every wake the `/factory` skill SHALL print a status table of every issue (state, workspace, PR, checks), including each worker's refusal or escalation with its reason, whose workspace stays in place.

#### Scenario: [agent-workflow-d7702e] The factory skill shows status and escalations
- **WHEN** `.claude/skills/factory/SKILL.md` is read
- **THEN** it prints the status table on every wake and reports a failed `worker_done` with its reason, keeping that workspace

#### Scenario: [agent-workflow-7eae70] A backlog runs to merged PRs unattended
- **WHEN** `/factory <label>` runs in a copy of the template with three issues of the label, one after another and one independent
- **THEN** the two free issues run in parallel workers, their PRs merge once green, and the dependent issue starts after its dependency merges and merges in turn
- **NO E2E** external: needs Orca, live Claude Code workers, a real GitHub repository and real merges, which CI cannot reach; proven by the recorded proof run in the PR
