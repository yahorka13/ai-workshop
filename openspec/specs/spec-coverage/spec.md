# spec-coverage Specification

## Purpose
How specs stay tied to proof: the end-to-end suite, scenario IDs, coverage of every scenario or its exclusion, proof captured from the running stack, and archiving changes.

## Requirements

### Requirement: Scenario IDs are well formed
`bin/check-spec-coverage.sh` SHALL fail, naming the file and the scenario,
when a scenario in `openspec/specs/` or in an active change's delta specs does
not start its name with `[<capability>-<n>]` or `[<capability>-<hash>]`, where
the capability is its spec folder (or, for a moved scenario, the capability it
was written in), `n` a positive integer and the hash 6 lowercase hex
characters with at least one letter.

#### Scenario: [spec-coverage-10e800] Malformed scenario ID
- **WHEN** a scenario has no ID, an ID for another capability that is not a moved scenario, or its ID anywhere but the start of its name
- **THEN** the spec-coverage check fails and names the file and the scenario

#### Scenario: [spec-coverage-1260aa] Malformed ID in an active change
- **WHEN** a delta spec in an active change has a scenario with a malformed ID
- **THEN** the spec-coverage check fails and names the change file and the scenario

#### Scenario: [spec-coverage-e55e80] Hash IDs are read against the capability folder
- **WHEN** a capability's scenarios carry hash IDs, including an all-letter hash such as `[widgets-beefed]`
- **THEN** the spec-coverage check accepts them, and rejects a number such as `[widgets-3]`, a hash of the wrong length, with upper-case letters, or with no letter

### Requirement: Scenario IDs are unique
`bin/check-spec-coverage.sh` SHALL fail, naming the ID, when two scenarios in
the main specs carry the same ID.

#### Scenario: [spec-coverage-bdaecf] Duplicate scenario ID
- **WHEN** two scenarios in the main specs carry the same ID
- **THEN** the spec-coverage check fails and names the ID

### Requirement: A moved scenario keeps its ID
A scenario that a change moves to another capability SHALL keep its ID, whose
prefix names the capability it was written in.

#### Scenario: [spec-coverage-b73968] A change moves a scenario to another capability
- **WHEN** an active change's delta for one capability carries a scenario whose ID names another capability and is carried by a scenario in the main specs
- **THEN** the spec-coverage check accepts it

### Requirement: A change borrows another capability's prefix only to move a scenario
`bin/check-spec-coverage.sh` SHALL reject a scenario in an active change's
delta whose ID names another capability, unless a scenario in the main specs
carries that ID.

#### Scenario: [spec-coverage-fae502] A new scenario borrows another capability's prefix
- **WHEN** an active change's delta carries a scenario whose ID names another capability and no scenario in the main specs carries that ID
- **THEN** the spec-coverage check fails, names the file and the scenario, and says to run `bin/scenario-id.sh <capability>`

### Requirement: Main specs accept the prefixes of live capabilities
A scenario in `openspec/specs/<capability>/spec.md` whose ID names another
capability SHALL be accepted only when that capability has a folder in
`openspec/specs/`.

#### Scenario: [spec-coverage-ecd608] A moved scenario of a live capability
- **WHEN** a main spec carries a scenario whose ID names another capability that has a folder in `openspec/specs/`
- **THEN** the spec-coverage check accepts it

#### Scenario: [spec-coverage-60707c] An unknown prefix in a main spec
- **WHEN** a main spec carries a scenario whose ID names a capability that has no folder in `openspec/specs/`
- **THEN** the spec-coverage check fails and names the file and the scenario

### Requirement: The change-archived check fails while a change of the issue is active
`bin/openspec-check-archived.sh <branch>` SHALL fail when any OpenSpec change of a change branch's issue, the branch's own or a sibling's, is not archived.

#### Scenario: [spec-coverage-5923b5] Unarchived change fails
- **WHEN** `openspec/changes/<branch>/` exists
- **THEN** the check prints a `::error::` that the change is not archived and exits 1

#### Scenario: [spec-coverage-0dc405] Missing change fails
- **WHEN** the change is neither in `openspec/changes/<branch>/` nor in `openspec/changes/archive/*-<branch>/`
- **THEN** the check prints a `::error::` that the change folder is missing and exits 1

#### Scenario: [spec-coverage-0c30cb] Archived change passes
- **WHEN** `openspec/changes/archive/<date>-<branch>/` exists and `openspec/changes/<branch>/` does not
- **THEN** the check exits 0

#### Scenario: [spec-coverage-73c973] Active sibling change fails
- **WHEN** the branch is `<N>-<hash>-<slug>`, its own change is archived, and another change `openspec/changes/<N>-<other hash>-<other slug>/` of the same issue is active
- **THEN** the check prints a `::error::` naming that change as not archived and exits 1
- **AND** an active change of another issue does not fail the check

### Requirement: The change-archived check passes a branch that is not a change branch
`bin/openspec-check-archived.sh <branch>` SHALL pass for branches that are not change branches.

#### Scenario: [spec-coverage-a47e0a] Non-change branch passes
- **WHEN** the branch does not match `<digits>-<6 hex>-`
- **THEN** the check prints "Not a change branch" and exits 0

### Requirement: Every scenario is cited by an end-to-end test or excluded
Each scenario in `openspec/specs/` SHALL be cited as `[<id>]`, one ID per
bracket, in an end-to-end test under `services/e2e/tests/` or `bin/tests/`, or
excluded by a `- **NO E2E** <category>: <reason>` line of its own, the
`spec-coverage` check failing otherwise, naming each scenario.

#### Scenario: [spec-coverage-e71ee5] Removing a scenario's test fails CI
- **WHEN** a PR removes the only end-to-end test citing a scenario that is not excluded
- **THEN** the `spec-coverage` check fails, names the scenario, and says to add a test citing it or an exclusion with a reason

#### Scenario: [spec-coverage-5e9cfb] A compressed citation covers only its first ID
- **WHEN** a test cites `[widgets-1, 2]`
- **THEN** only `widgets-1` counts as cited

#### Scenario: [spec-coverage-c9cec7] A hash ID is cited like a number
- **WHEN** an end-to-end test cites `[widgets-3f9c1a]` or `[widgets-beefed, widgets-2]`
- **THEN** `widgets-3f9c1a` and `widgets-beefed` count as cited

### Requirement: Only end-to-end citations count
Citations of a scenario outside the end-to-end tests under `services/e2e/tests/` and `bin/tests/` SHALL NOT count as covering it.

#### Scenario: [spec-coverage-4d6888] Only end-to-end citations count
- **WHEN** a scenario is cited only in a service's unit or integration tests
- **THEN** the spec-coverage check reports it as not covered

### Requirement: An exclusion line names a category and a reason
A scenario's exclusion SHALL be one line, `- **NO E2E** <category>: <reason>`,
after its WHEN and THEN lines in the main spec, with a category of
`internal-rule`, `not-built` or `external`; the check fails on any other
form.

#### Scenario: [spec-coverage-b28b5c] Exclusion without a category or reason
- **WHEN** a scenario's `NO E2E` line has no category, a category outside `internal-rule`, `not-built` and `external`, or no reason
- **THEN** the spec-coverage check fails, names the spec file and line and lists the categories

### Requirement: An internal-rule exclusion names its test file
An `internal-rule` exclusion's reason SHALL name an existing test file.

#### Scenario: [spec-coverage-195ea5] An internal rule names the test that covers it
- **WHEN** an `internal-rule` exclusion's reason names no test file, or one that does not exist
- **THEN** the spec-coverage check fails and names the spec file and line

### Requirement: A scenario is excluded once, by a line inside it
The spec-coverage check SHALL fail on a `NO E2E` line outside a scenario, or on a second one in the same scenario.

#### Scenario: [spec-coverage-3c7c6b] A stray or repeated exclusion
- **WHEN** a `NO E2E` line stands under a requirement's text instead of a scenario, or a scenario has two
- **THEN** the spec-coverage check fails and names the line or the scenario's ID

### Requirement: A cited scenario leaves the exclusions
The spec-coverage check SHALL fail on an excluded ID that an end-to-end test now cites.

#### Scenario: [spec-coverage-bd4e42] A covered scenario leaves the exclusions
- **WHEN** an end-to-end test cites a scenario that is also excluded
- **THEN** the spec-coverage check fails and says to remove the exclusion line

### Requirement: The generator prints fresh scenario IDs
`bin/scenario-id.sh <capability> [<count>]` SHALL print `<count>` (default 1)
fresh IDs for a capability, one per line, none used by that capability in
`openspec/specs/` or an active change's delta specs and none repeated.

#### Scenario: [spec-coverage-a3334a] Fresh IDs for a capability
- **WHEN** a developer runs `bin/scenario-id.sh widgets 3`
- **THEN** it prints three distinct IDs of the form `widgets-<6 hex with a letter>`, none carried by a scenario in the main specs or an active change

### Requirement: The generator refuses an unknown capability or a bad count
`bin/scenario-id.sh` SHALL fail, with its usage, on a capability that has no spec folder in `openspec/specs/` or an active change's delta specs, and on a bad count.

#### Scenario: [spec-coverage-bc5727] Unknown capability
- **WHEN** a developer runs `bin/scenario-id.sh` with a capability that has no spec folder in `openspec/specs/` or an active change, or with a count that is not a positive integer
- **THEN** it fails, prints its usage, and prints no ID

### Requirement: Archiving needs every task ticked
`bin/openspec-archive <change-id>` SHALL archive a change only when every task line of its `tasks.md` is ticked, counting task lines the way OpenSpec does; on a refusal it lists each offending task with its line number, exits non-zero and leaves the change unarchived.

#### Scenario: [spec-coverage-b1f5d7] Unchecked task refuses the archive
- **WHEN** `bin/openspec-archive` runs on a change whose `tasks.md` has an unchecked task
- **THEN** it exits non-zero, prints the task's line number and text, and the change stays in `openspec/changes/`

#### Scenario: [spec-coverage-f94993] Finished change is archived
- **WHEN** `bin/openspec-archive` runs on a valid change whose tasks are all ticked
- **THEN** the change moves to `openspec/changes/archive/` and its deltas merge into `openspec/specs/`

### Requirement: A dropped task gives its reason
A ticked task that starts with `Dropped:` MUST give a reason after it.

#### Scenario: [spec-coverage-1d435f] Dropped task with a reason is archived
- **WHEN** a change's only unfinished work is a task written `- [x] 2.1 Dropped: <reason>. <task>`
- **THEN** `bin/openspec-archive` archives the change

#### Scenario: [spec-coverage-0e7bab] Dropped task without a reason refuses the archive
- **WHEN** a change has a ticked task that says `Dropped:` with no reason after it
- **THEN** `bin/openspec-archive` exits non-zero, prints that task's line, and the change stays in `openspec/changes/`

### Requirement: bin/e2e runs the suite against the worktree's stack
`bin/e2e` SHALL run the `services/e2e` Playwright suite in its pinned image against the stack `bin/up` started for this worktree, keep the report and traces in `tmp/e2e/<run>/`, print that path, and exit with the suite's result.

#### Scenario: [spec-coverage-d72d48] A passing suite keeps its report
- **WHEN** `bin/e2e` runs while this worktree's stack is up and every test passes
- **THEN** it exits 0 and prints the `tmp/e2e/<run>/` folder that holds `playwright-report/` and `test-results/`

#### Scenario: [spec-coverage-762db8] A failing test fails the run
- **WHEN** `bin/e2e` runs and a test fails
- **THEN** it exits nonzero, keeps the report in `tmp/e2e/<run>/` and names its `playwright-report/index.html`

#### Scenario: [spec-coverage-54237b] The run leaves no container or image
- **WHEN** a `bin/e2e` run ends, passed, failed or interrupted
- **THEN** the container and the image it built for that run are removed

### Requirement: The suite reaches the stack at the slot's URLs
`bin/e2e` SHALL run the suite on the stack's own network with the app at `http://<FACTORY_PUBLIC_HOST>:<FACTORY_PORT_UI>` and the API at `http://<FACTORY_PUBLIC_HOST>:<FACTORY_PORT_API>`, reached inside the container through forwarders to the ui and backend services, so no host networking is needed and the browser's origins are those of a developer's browser.

#### Scenario: [spec-coverage-2183dd] The suite gets the slot's URLs without host networking
- **WHEN** `bin/e2e` starts the suite for a stack whose slot publishes the ui on port 16000 and the API on port 16002 at `127.0.0.1`
- **THEN** the container joins the stack's Compose network, not the host's, and receives `E2E_BASE_URL=http://127.0.0.1:16000`, `E2E_API_URL=http://127.0.0.1:16002` and forwards from those ports to `ui:3000` and `backend:4000`

#### Scenario: [spec-coverage-746b78] A public host name resolves to the forwarders
- **WHEN** the stack's `FACTORY_PUBLIC_HOST` is a name other than `127.0.0.1`
- **THEN** the container resolves that name to its own `127.0.0.1` and the suite's URLs use the name

### Requirement: bin/e2e refuses without a running stack
`bin/e2e` SHALL refuse to run the suite, without building anything, when this worktree has no `.env.session` or its stack's `ui` service is not running, and say to run `bin/up`.

#### Scenario: [spec-coverage-a3ede3] No stack, no run
- **WHEN** `bin/e2e` runs in a worktree without `.env.session`, or with one whose `ui` is not running
- **THEN** it exits 1, says to start the stack with `bin/up`, and starts no container

### Requirement: bin/e2e passes Playwright arguments through
`bin/e2e` SHALL pass every argument after `--` to `playwright test` unchanged.

#### Scenario: [spec-coverage-a905e7] A grep reaches Playwright
- **WHEN** `bin/e2e -- --grep "\[app-shell-af1ebe\]"` runs
- **THEN** the suite's container runs `playwright test --grep "\[app-shell-af1ebe\]"`

### Requirement: bin/e2e --gates checks the suite without a stack
`bin/e2e --gates` SHALL build the suite's image and run its lint and then its typecheck in it, without a running stack, failing on the first that fails and naming it.

#### Scenario: [spec-coverage-ab430a] Gates run lint then typecheck
- **WHEN** `bin/e2e --gates` runs in a worktree with no stack
- **THEN** it runs `bun run lint` and then `bun run typecheck` in the suite's image and exits 0 when both pass

#### Scenario: [spec-coverage-230e5d] A failed gate fails the run
- **WHEN** the suite's lint fails under `bin/e2e --gates`
- **THEN** it exits 1, names lint as the failed phase, and does not run the typecheck

### Requirement: bin/e2e --changed runs only the changed capabilities' tests
`bin/e2e --changed` SHALL run only the tests citing a scenario of a capability whose specs the branch changes, the active changes' deltas included, and print the capabilities it picked.

#### Scenario: [spec-coverage-5cf1ec] Only the changed capability runs
- **WHEN** the branch changes the `app-shell` spec and the suite cites scenarios of `app-shell` and `service-checks`
- **THEN** `bin/e2e --changed` prints `app-shell` as changed and passes Playwright one `--grep` matching only the cited `app-shell` scenario IDs

#### Scenario: [spec-coverage-df6711] A change's delta counts
- **WHEN** the only spec change is an active change's delta adding a scenario to `app-shell`
- **THEN** `bin/e2e --changed` picks `app-shell`, and its grep includes the new scenario's ID once the suite cites it

#### Scenario: [spec-coverage-15915f] Extra arguments still pass through
- **WHEN** `bin/e2e --changed -- --workers 1` runs
- **THEN** Playwright gets the changed capabilities' grep and `--workers 1`

### Requirement: bin/e2e --changed runs everything when no spec changes
`bin/e2e --changed` SHALL run the full suite, saying so, when the branch changes no specs.

#### Scenario: [spec-coverage-c85dc1] No spec change runs everything
- **WHEN** `bin/e2e --changed` runs on a branch that changes no spec and has no active change deltas
- **THEN** it says the branch changes no specs and runs the suite with no grep

### Requirement: bin/e2e --changed runs nothing for uncited capabilities
`bin/e2e --changed` SHALL name the changed capabilities no suite test cites, and exit 0 without starting the suite when none of the changed capabilities is cited.

#### Scenario: [spec-coverage-dc0f63] Only uncited capabilities run nothing
- **WHEN** the branch changes only the `ci` spec and no suite test cites a `ci` scenario
- **THEN** `bin/e2e --changed` names `ci` as having no end-to-end tests in the suite, says there is nothing to run, starts no container and exits 0

### Requirement: bin/e2e refuses conflicting selections
`bin/e2e` SHALL exit 2 with its usage when `--changed` is combined with `--gates` or with a `--grep` passed through, when `--gates` is given Playwright arguments, or when an option is unknown.

#### Scenario: [spec-coverage-6144af] Conflicting selections are refused
- **WHEN** `bin/e2e --changed -- --grep x`, `bin/e2e --changed --gates`, `bin/e2e --gates -- --grep x` or `bin/e2e --nope` runs
- **THEN** it exits 2, prints its usage, and runs nothing

### Requirement: bin/e2e describes itself
`bin/e2e --help` SHALL print its usage: the suite run, `--changed`, `--gates`, passing arguments after `--`, where reports land, and that it needs Docker and a stack from `bin/up`.

#### Scenario: [spec-coverage-a93813] Help names the modes
- **WHEN** `bin/e2e --help` runs
- **THEN** it exits 0 and its output names `--changed`, `--gates`, `--`, `tmp/e2e/` and `bin/up`

### Requirement: bin/e2e --proof saves a screenshot per passing test
`bin/e2e --proof` SHALL, when the suite passes, copy one screenshot of each passing test into the proof change's `proof/` folder, named after the test's title with its scenario IDs first, and print each file it wrote.

#### Scenario: [spec-coverage-de027b] Proof lands in the change
- **WHEN** `bin/e2e --proof -- --grep "\[app-shell-af1ebe\]"` passes for the test `[app-shell-af1ebe] the home screen shows the layout`
- **THEN** `openspec/changes/<change>/proof/app-shell-af1ebe-the-home-screen-shows-the-layout.png` exists and is printed, and no video is written

#### Scenario: [spec-coverage-9c88ca] A failing proof run copies nothing
- **WHEN** `bin/e2e --proof` runs and a test fails
- **THEN** it exits nonzero and writes nothing to the change's `proof/` folder

### Requirement: bin/e2e --proof --video also records a video
`bin/e2e --proof --video` SHALL also copy each passing test's video next to its screenshot, under the same name.

#### Scenario: [spec-coverage-f21527] Video only on request
- **WHEN** `bin/e2e --proof --video` passes
- **THEN** each proof screenshot has a `.webm` video of the same name beside it

### Requirement: The proof change is the one named, the branch's or the only one
`bin/e2e --proof` SHALL write into `--change <id>` when given, active or archived, else the change the branch is named after, else the only active change, and refuse when it cannot tell.

#### Scenario: [spec-coverage-babb03] The flag picks the change
- **WHEN** `bin/e2e --proof --change 7-1ca398-pr-proof` runs on the branch `7-2159c5-e2e-suite`
- **THEN** the proof goes to `openspec/changes/7-1ca398-pr-proof/proof/`

#### Scenario: [spec-coverage-b9a4f9] The branch's change by default
- **WHEN** `bin/e2e --proof` runs on a branch named after an active change, with other changes active
- **THEN** the proof goes to that change's `proof/` folder

#### Scenario: [spec-coverage-a0d88a] An archived change takes new proof
- **WHEN** `bin/e2e --proof --change <id>` names a change that is only in `openspec/changes/archive/<date>-<id>/`
- **THEN** the proof goes to that archived folder's `proof/`

#### Scenario: [spec-coverage-aa818f] No change to hold the proof
- **WHEN** `bin/e2e --proof` runs on a branch named after no change while two changes are active, or `--change` names no change
- **THEN** it exits 1 before running the suite and says to pass `--change <id>`

### Requirement: Proof options need --proof
`bin/e2e` SHALL exit 2 with its usage when `--change` or `--video` is given without `--proof`, or `--proof` with `--changed` or `--gates`.

#### Scenario: [spec-coverage-e39d27] Proof options alone are refused
- **WHEN** `bin/e2e --video`, `bin/e2e --change x`, `bin/e2e --proof --changed` or `bin/e2e --proof --gates` runs
- **THEN** it exits 2, prints its usage and runs nothing

### Requirement: bin/proof-markdown prints the PR's proof section
`bin/proof-markdown <ref>` SHALL print a `## Proof` section with one entry per proof file the branch adds since its merge base with `origin/main` under an active or archived change's `proof/` folder at `<ref>`: an inline image for a screenshot and a link for a video, each a commit permalink in the repository `bin/repo` names.

#### Scenario: [spec-coverage-acc3ac] Proof files become permalinks
- **WHEN** a commit holds `openspec/changes/<change>/proof/x.png` and `x.webm`
- **THEN** `bin/proof-markdown <ref>` prints `## Proof`, one entry `x` with the image `https://github.com/<owner>/<repo>/blob/<sha>/openspec/changes/<change>/proof/x.png?raw=true` and a `[Video](...)` link to the `.webm` at the same commit

#### Scenario: [spec-coverage-7eef0b] Archived proof is found
- **WHEN** the proof files sit in `openspec/changes/archive/<date>-<change>/proof/` at `<ref>`
- **THEN** `bin/proof-markdown <ref>` lists them with permalinks to the archived paths

#### Scenario: [spec-coverage-677a6a] Older proof is left out
- **WHEN** `origin/main` already holds an archived change's proof and the branch adds proof to its own change
- **THEN** `bin/proof-markdown <ref>` lists only the branch's proof

#### Scenario: [spec-coverage-0c1f35] No proof files
- **WHEN** the branch adds no proof file under any change since its merge base with `origin/main`
- **THEN** `bin/proof-markdown <ref>` exits 1 and says to capture them with `bin/e2e --proof` and commit them

### Requirement: Each proof is captioned with its scenario
`bin/proof-markdown` SHALL head each proof named after a scenario ID with that ID, the scenario's title and its expected outcome (its THEN and AND lines), read at the ref from `openspec/specs/` or an active change.

#### Scenario: [spec-coverage-d54754] A proof is captioned
- **WHEN** a proof is named `app-shell-c88136-an-unknown-path-is-not-found.png`
- **THEN** its entry is headed `### [app-shell-c88136] An unknown path is not found` followed by `Expected: ` and the scenario's THEN line

#### Scenario: [spec-coverage-1028ae] A scenario still in its change is found
- **WHEN** a proof names a scenario that exists only in an active change's delta spec at the ref
- **THEN** the caption comes from that delta

#### Scenario: [spec-coverage-83cedb] A name that is no scenario keeps its name
- **WHEN** a proof file's name starts with no scenario ID known at the ref
- **THEN** its entry is headed with the file's name and has no caption
