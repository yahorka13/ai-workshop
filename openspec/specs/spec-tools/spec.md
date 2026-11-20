# spec-tools Specification

## Purpose
Tools that read and check the OpenSpec specs for agents and reviewers: finding one requirement or scenario, showing what a branch changed, and guarding how requirements are written.

## Requirements

### Requirement: Find a requirement or scenario
`bin/spec find <query>` SHALL print, for each requirement or scenario whose
ID, name or text matches the query, its capability, its requirement name and
its file and line.

#### Scenario: [spec-tools-ba6659] Find by scenario ID
- **WHEN** `bin/spec find` runs with a scenario ID a spec carries
- **THEN** it prints that scenario's capability, requirement name and `openspec/specs/<capability>/spec.md:<line>`

#### Scenario: [spec-tools-86cd51] Find by text
- **WHEN** `bin/spec find` runs with a word that appears in two requirements' text
- **THEN** it prints both, each with its capability, requirement name and file and line

#### Scenario: [spec-tools-22d65d] Nothing matches
- **WHEN** `bin/spec find` runs with a query no requirement or scenario matches
- **THEN** it prints that nothing matched and exits 1

### Requirement: Show one requirement
`bin/spec show <scenario-id | requirement name>` SHALL print one requirement,
its text and its scenarios, without the rest of its spec.

#### Scenario: [spec-tools-00bcf7] Show by scenario ID
- **WHEN** `bin/spec show` runs with a scenario ID
- **THEN** it prints the requirement that holds the scenario, its text and all its scenarios

#### Scenario: [spec-tools-076c1c] Show by requirement name
- **WHEN** `bin/spec show` runs with a requirement's name in any letter case
- **THEN** it prints that requirement, its text and its scenarios

#### Scenario: [spec-tools-64feb3] An ambiguous name
- **WHEN** `bin/spec show` runs with a name that is part of several requirements' names and equal to none
- **THEN** it lists the matching requirements with their capabilities and exits 1

### Requirement: List what a branch changed in the specs
`bin/spec changed [--base <ref>]` SHALL list the requirements and scenarios
in `openspec/specs/` that were added, modified, removed or moved between
`<ref>` and the working tree, with the merge base of `origin/main` as the
default `<ref>`.

#### Scenario: [spec-tools-9e1f9b] Changes made by archiving
- **WHEN** a branch archives a change that adds one requirement and modifies another, and `bin/spec changed --base` runs with the branch's base
- **THEN** it lists the first as added and the second as modified, each with its capability

#### Scenario: [spec-tools-13bfa8] A requirement moved to another capability
- **WHEN** a requirement's name and text are unchanged but it sits in another capability than at the base
- **THEN** `bin/spec changed` lists it as moved, naming both capabilities, and not as added or removed

#### Scenario: [spec-tools-51d404] A changed scenario
- **WHEN** only one scenario of a requirement differs from the base
- **THEN** `bin/spec changed` lists the requirement as modified and names that scenario's ID

#### Scenario: [spec-tools-bf9ba7] No change
- **WHEN** `openspec/specs/` is the same as at the base
- **THEN** `bin/spec changed` prints that the specs did not change and exits 0

### Requirement: List the active changes' pending deltas
`bin/spec changed` SHALL list, under each active change, the requirements its
delta specs add, modify, remove or rename.

#### Scenario: [spec-tools-710d45] A change not archived yet
- **WHEN** an active change's delta adds one requirement and removes another
- **THEN** `bin/spec changed` lists both under the change's name, with their operations and capabilities

### Requirement: Review packet for a branch
`bin/spec review [--base <ref>]` SHALL print, for each requirement that
`bin/spec changed` reports, its capability's Purpose, its text, its scenarios
and, for each scenario, the end-to-end tests citing it or its exclusion line.

#### Scenario: [spec-tools-6cdd2f] A changed requirement with a cited scenario
- **WHEN** a branch modifies a requirement whose scenario is cited by a test under `services/e2e/tests/`
- **THEN** `bin/spec review` prints the capability's Purpose, the requirement, its scenarios and that test file under the scenario

#### Scenario: [spec-tools-caec5d] An excluded scenario
- **WHEN** a changed requirement's scenario carries a `- **NO E2E**` exclusion line
- **THEN** `bin/spec review` prints the exclusion's category and reason under the scenario

### Requirement: Machine-readable output
`bin/spec find`, `bin/spec show` and `bin/spec changed` SHALL print JSON
instead of text when given `--json`.

#### Scenario: [spec-tools-d7c38a] JSON from show
- **WHEN** `bin/spec show --json` runs with a scenario ID
- **THEN** it prints one JSON object with the capability, the requirement's name and text, and its scenarios

### Requirement: bin/spec describes itself
`bin/spec --help` and each subcommand's `--help` SHALL print its usage without
reading the specs.

#### Scenario: [spec-tools-f6c9fb] Help without a spec tree
- **WHEN** `bin/spec --help` or `bin/spec find --help` runs outside a repository
- **THEN** it prints the usage and exits 0

### Requirement: A requirement's obligations are its normative keywords
`bin/check-spec-obligations.sh` SHALL call a requirement bundled when its
text outside its scenarios, code spans and quotes holds more than one `SHALL`
or `MUST` keyword, with `SHALL NOT` and `MUST NOT` counting once.

#### Scenario: [spec-tools-26dd7c] Two obligations in one requirement
- **WHEN** a requirement's text says "The service SHALL log the request. It MUST NOT log the token."
- **THEN** the check counts two obligations and calls the requirement bundled

#### Scenario: [spec-tools-84c073] Keywords in scenarios do not count
- **WHEN** a requirement's text has one SHALL and its scenarios contain the word SHALL
- **THEN** the check counts one obligation

#### Scenario: [spec-tools-41cd27] Keywords quoted in the text do not count
- **WHEN** a requirement's text has one SHALL and also names the keywords as `SHALL` in a code span or "MUST" in quotes
- **THEN** the check counts one obligation

### Requirement: Changes add only single-obligation requirements
`bin/check-spec-obligations.sh` SHALL fail when an active change's delta adds
or modifies a bundled requirement, naming the change file and line and saying
to split it into one requirement per `SHALL` or `MUST`.

#### Scenario: [spec-tools-b33e00] A change adds a bundled requirement
- **WHEN** an active change's delta adds a requirement with two SHALLs
- **THEN** the check fails, names the delta file and the requirement's line, and says to split it into one requirement per SHALL or MUST

#### Scenario: [spec-tools-3828ea] A change adds single-obligation requirements
- **WHEN** every requirement an active change adds or modifies has one SHALL or MUST
- **THEN** the check passes

### Requirement: Archived work adds only single-obligation requirements
`bin/check-spec-obligations.sh --base <ref>` SHALL fail when a requirement in
`openspec/specs/` whose text was added or changed since `<ref>` is bundled; a
change to its scenarios alone leaves it as it was.

#### Scenario: [spec-tools-982d5e] A bundled requirement arrives by archive
- **WHEN** a branch archives a change, so that `openspec/specs/` gains a bundled requirement it did not have at the base
- **THEN** the check with `--base` fails and names the spec file and the requirement's line

### Requirement: Moving a requirement unchanged does not introduce it
`bin/check-spec-obligations.sh` SHALL NOT report a bundled requirement as
added or modified when the same name and text exist in another capability at
the base or in the main specs.

#### Scenario: [spec-tools-e6451d] A bundled requirement moves capability
- **WHEN** a change removes a bundled requirement from one capability and adds it, word for word, to another
- **THEN** the check does not report it

### Requirement: The pre-commit hook checks obligations when specs are staged
The pre-commit hook SHALL run `bin/check-spec-obligations.sh` when the commit
stages a file under `openspec/`, and only then.

#### Scenario: [spec-tools-53b52e] A commit stages a bundled requirement
- **WHEN** a commit stages an active change's delta that adds a bundled requirement
- **THEN** the pre-commit hook rejects the commit with the check's message

#### Scenario: [spec-tools-afc18b] A commit without spec files
- **WHEN** a commit stages no file under `openspec/`
- **THEN** the pre-commit hook does not run the check

### Requirement: Spec instructions state one obligation per requirement
The spec rules in `openspec/config.yaml` and the `factory` schema's spec
template SHALL state that a requirement holds one obligation and a second
`SHALL` or `MUST` is a second requirement.

#### Scenario: [spec-tools-91e7a8] An agent writes a spec
- **WHEN** an agent reads `bin/openspec instructions specs` for a change
- **THEN** the instructions say one obligation per requirement, and a second SHALL or MUST is a second requirement
