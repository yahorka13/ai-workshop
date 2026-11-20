# contracts Specification

## Purpose
The committed, machine-readable contracts that are the only coupling between services: how a producer generates and checks them, and how consumers read them.

## Requirements

### Requirement: The backend commits its GraphQL schema
The backend SHALL commit `contracts/schema.graphql`, generated from its schema code, with its types and fields sorted.

#### Scenario: [contracts-d364e3] The committed SDL matches the schema
- **WHEN** `bun run contracts` runs in a clean backend checkout
- **THEN** it exits 0, and `contracts/schema.graphql` holds the `health` query and the `Health` type in sorted order
- **NO E2E** internal-rule: services/backend/tests/integration/contracts.test.ts

### Requirement: Generated contracts are validated
Contract generation SHALL refuse to write a GraphQL schema that does not parse and build.

#### Scenario: [contracts-a7e939] An invalid schema is rejected
- **WHEN** the printed schema does not build
- **THEN** generation exits nonzero naming the error and the committed file is unchanged
- **NO E2E** internal-rule: services/backend/tests/unit/contracts.test.ts

### Requirement: Stale generated files fail the contract check
`bun run contracts` SHALL fail, naming the file, when a generated file differs from what generation produces.

#### Scenario: [contracts-a3b248] A changed producer source fails
- **WHEN** a field is added to the schema code and `contracts/` is not regenerated
- **THEN** `bun run contracts` exits nonzero naming `contracts/schema.graphql`
- **NO E2E** internal-rule: services/backend/tests/integration/contracts.test.ts

#### Scenario: [contracts-5233fe] A hand-edited generated file fails
- **WHEN** `contracts/schema.graphql` is edited by hand
- **THEN** `bun run contracts` exits nonzero naming the file
- **NO E2E** internal-rule: services/backend/tests/integration/contracts.test.ts

#### Scenario: [contracts-1df7a5] Regenerated files pass
- **WHEN** `bun run contracts:generate` has run after the change
- **THEN** `bun run contracts` exits 0
- **NO E2E** internal-rule: services/backend/tests/integration/contracts.test.ts

### Requirement: Generated files are marked
Every generated contract file SHALL begin with a notice that it is generated and how to regenerate it.

#### Scenario: [contracts-ed0454] The SDL carries the notice
- **WHEN** `contracts/schema.graphql` is read
- **THEN** its first lines say it is generated and name `bin/contracts generate`
- **NO E2E** internal-rule: services/backend/tests/integration/contracts.test.ts

### Requirement: Generated files are excluded from formatting, lint and coverage
A service's formatter, lint and coverage configuration SHALL skip its generated contract files, each exclusion with a comment saying why.

#### Scenario: [contracts-5ec35e] Generated files are skipped with a reason
- **WHEN** the backend's Prettier ignore file, ESLint config and coverage settings are read
- **THEN** each excludes `contracts/` with a comment giving the reason

#### Scenario: [contracts-15fd30] The UI's generated types are skipped with a reason
- **WHEN** the ui's Prettier ignore file, ESLint config and coverage settings are read
- **THEN** each excludes `src/services/graphql/generated/` with a comment giving the reason

### Requirement: GraphQL fields follow the naming rule
Every backend root field SHALL follow the naming rule unless it is listed with a reason as an exception: a query is named after the resource it returns with no verb, and a mutation starts with `create`, `update` or `delete`.

#### Scenario: [contracts-86cd7d] A verb-named query fails
- **WHEN** the schema has a query named `getContacts`
- **THEN** the naming test fails naming the field
- **NO E2E** internal-rule: services/backend/tests/unit/contracts-schema.test.ts

### Requirement: Contract generation needs no network
`bin/contracts generate` SHALL run each service's generation in its checks container with no network and no credentials.

#### Scenario: [contracts-2f43a2] Generation runs offline
- **WHEN** `bin/contracts generate` runs
- **THEN** every generation container is started with `--network none` and no environment file

### Requirement: bin/contracts regenerates producers, then their consumers
`bin/contracts generate` SHALL regenerate every service with a `contracts:generate` script, each producer before the consumers that declare it, replacing each folder the script reports.

#### Scenario: [contracts-f07555] Producers regenerate before consumers
- **WHEN** a consumer declares the backend in `consumes.txt` and `bin/contracts generate` runs
- **THEN** the backend generates first, the consumer second with the backend's fresh contracts mounted, and each reported `generated: <folder>` replaces that folder

#### Scenario: [contracts-bcf2fc] A failed generation keeps the files
- **WHEN** one service's generation fails or reports a folder outside the service
- **THEN** the run exits nonzero and that service's folders are left as they were

#### Scenario: [contracts-e2f420] A cycle is refused
- **WHEN** two services declare each other
- **THEN** `bin/contracts generate` exits nonzero naming the cycle before generating anything

### Requirement: bin/contracts validates its input before Docker
`bin/contracts` SHALL print its usage on `--help` and exit 2 on any argument other than `generate`, without calling Docker.

#### Scenario: [contracts-25aef9] Help and invalid input are local
- **WHEN** `bin/contracts` runs with `--help`, with no argument, then with `check`
- **THEN** it prints usage and exits 0, then 2, then 2, and Docker is never called

### Requirement: Declared producer contracts are mounted read-only
`bin/check` and `bin/contracts` SHALL mount each producer a consumer lists in `consumes.txt` read-only at `/contracts/<producer>/`.

#### Scenario: [contracts-9289fc] Declared contracts are mounted read-only
- **WHEN** a consumer's `consumes.txt` lists `backend` with a comment and a blank line
- **THEN** its check and generation containers mount `services/backend/contracts` read-only at `/contracts/backend/`

### Requirement: A declared producer without contracts fails early
`bin/check` and `bin/contracts` SHALL exit nonzero, before building, when `consumes.txt` names a service with no `contracts/` folder.

#### Scenario: [contracts-d55f7d] An unknown producer fails early
- **WHEN** a consumer's `consumes.txt` lists `nosuch`
- **THEN** `bin/check` on it exits nonzero naming `nosuch` and no image is built

### Requirement: The UI's GraphQL types come from the backend's contract
The ui SHALL generate the types of its GraphQL operations from the backend's committed `contracts/schema.graphql`, into a committed folder marked as generated.

#### Scenario: [contracts-adbbb1] The UI generates from the backend's schema
- **WHEN** `bin/contracts generate` runs in a clean working copy
- **THEN** the backend's contract is regenerated first, then the ui's `src/services/graphql/generated/`, every file carries the generated notice, and nothing else changes

### Requirement: A stale UI generated folder fails the contract check
The ui's `bun run contracts` SHALL fail, naming the file, when its generated folder differs from what generation produces from the mounted backend contract.

#### Scenario: [contracts-de85d3] A changed backend contract fails the UI's check
- **WHEN** the backend's `contracts/schema.graphql` gains a field the ui's operations select and the ui is not regenerated
- **THEN** `bin/check ui --gates contracts` exits nonzero naming a file under `src/services/graphql/generated/`
- **NO E2E** internal-rule: services/ui/tests/integration/contracts.test.ts

#### Scenario: [contracts-b276f4] A hand-edited UI generated file fails
- **WHEN** a file under `src/services/graphql/generated/` is edited by hand
- **THEN** `bun run contracts` exits nonzero naming the file
- **NO E2E** internal-rule: services/ui/tests/integration/contracts.test.ts

### Requirement: A UI operation must match the backend's schema
The ui's contract generation SHALL fail when an operation selects a field the backend's schema does not have.

#### Scenario: [contracts-5a11b7] An unknown field fails generation
- **WHEN** an operation under `src/services/graphql/` selects `health { noSuchField }`
- **THEN** `bun run contracts` and `bun run contracts:generate` exit nonzero naming the field and the generated folder is unchanged
- **NO E2E** internal-rule: services/ui/tests/integration/contracts.test.ts

### Requirement: The API refuses a query nested too deep
The API SHALL refuse, without executing it, a GraphQL operation whose field selections nest deeper than 8 levels, counting fields reached through fragments at their real depth, with an error whose `extensions.code` is `QUERY_TOO_COMPLEX` and whose message states the depth and the limit.

#### Scenario: [contracts-6add5c] A query 9 levels deep is refused
- **WHEN** a client sends a query whose deepest field is at level 9, part of it through a fragment
- **THEN** the answer has no `data`, one error with `extensions.code` `QUERY_TOO_COMPLEX` naming the limit of 8, and no resolver runs
- **NO E2E** internal-rule: services/backend/tests/unit/limits.test.ts

#### Scenario: [contracts-4f83fa] A query at the depth limit runs
- **WHEN** a client sends a valid query whose deepest field is at level 8 or less
- **THEN** it executes as without the limit

### Requirement: The API refuses a query selecting too many fields
The API SHALL refuse, without executing it, a GraphQL operation that selects more than 100 fields, counting each alias and each field of a fragment at every spread, with an error whose `extensions.code` is `QUERY_TOO_COMPLEX` and whose message states the count and the limit.

#### Scenario: [contracts-e79819] Aliasing a field past the limit is refused
- **WHEN** a client sends a query with 101 aliased `health { ok }` selections
- **THEN** the answer has no `data`, one error with `extensions.code` `QUERY_TOO_COMPLEX` naming the limit of 100, and no resolver runs

#### Scenario: [contracts-d1de56] A query within the field limit runs
- **WHEN** a client sends the dashboard query the UI sends
- **THEN** it executes as without the limit

### Requirement: Introspection is not limited
The API SHALL exempt the fields under an introspection root (`__schema`, `__type`) from the depth and field limits.

#### Scenario: [contracts-f0fd4e] A deep introspection query is not refused by the limits
- **WHEN** a client sends an introspection query nested deeper than 8 levels
- **THEN** the answer carries no `QUERY_TOO_COMPLEX` error, whether introspection is enabled or not
