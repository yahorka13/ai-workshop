# service-checks Specification

## Purpose
How every service under `services/` is laid out and checked: its isolation, runtime pin, standard scripts, strict typecheck, lint, test policy, coverage and container targets, and the commands that run those gates.

## Requirements

### Requirement: Each service is isolated in its own folder
Every service SHALL live in `services/<name>/` with its own `package.json`, lockfile, Dockerfile and `AGENTS.md`, and import nothing from another service's folder.

#### Scenario: [service-checks-8d88cc] A service folder holds what it needs
- **WHEN** the repository's service folders are inspected
- **THEN** each one other than `services/e2e` has a `package.json`, a `bun.lock`, a `Dockerfile` and an `AGENTS.md`, and no source file under it imports a path in another service's folder

### Requirement: A service pins its Bun runtime
A service's `package.json` SHALL pin one exact Bun version in `engines.bun`, the version its Dockerfile's base image carries.

#### Scenario: [service-checks-e156cb] The engine and the image agree
- **WHEN** a service's `package.json` and Dockerfile are read
- **THEN** `engines.bun` is an exact version and the Dockerfile's base image is `oven/bun` at that same version

### Requirement: Services share the standard scripts
Every service with a checks target SHALL define the package scripts `lint`, `format`, `typecheck`, `test:unit`, `test:integration`, `coverage`, `duplicates`, `unused` and `imports`.

#### Scenario: [service-checks-56c271] The standard scripts exist
- **WHEN** the `package.json` of a service with a checks target is read
- **THEN** it defines `lint`, `format`, `typecheck`, `test:unit`, `test:integration`, `coverage`, `duplicates`, `unused` and `imports`

### Requirement: Typecheck is strict
A service's typecheck SHALL fail on implicit `any`, unchecked indexed access, a missing return, a missing `override` and a switch fallthrough.

#### Scenario: [service-checks-3b5dea] Unsafe code fails the typecheck
- **WHEN** a source file reads an array element as defined without a check, or a function misses a return on one path
- **THEN** `bun run typecheck` exits nonzero naming the file
- **NO E2E** internal-rule: services/backend/tests/integration/gates.test.ts

### Requirement: Lint rejects warnings and formatting differences
A service's `lint` script SHALL fail on any lint error or warning and on any file Prettier would change, without writing.

#### Scenario: [service-checks-a8c50a] Lint and formatting are enforced
- **WHEN** a source file has a lint warning or is not formatted
- **THEN** `bun run lint` exits nonzero and the file is unchanged
- **NO E2E** internal-rule: services/backend/tests/integration/gates.test.ts

### Requirement: Type-aware lint rejects unsafe code
A service's lint SHALL run the type-aware strict rules, rejecting unsafe type assertions, non-boolean conditions and non-exhaustive switches.

#### Scenario: [service-checks-7b0f32] Unsafe code fails lint
- **WHEN** a source file asserts a type with `as`, branches on a nullable number, or switches over a union without every member
- **THEN** `bun run lint` exits nonzero naming the rule
- **NO E2E** internal-rule: services/backend/tests/integration/gates.test.ts

### Requirement: Module boundaries declare their types
A service's lint SHALL fail on an exported function without a declared return type.

#### Scenario: [service-checks-2fe7bd] An undeclared boundary type fails lint
- **WHEN** a module exports a function with no return type
- **THEN** `bun run lint` exits nonzero naming the function
- **NO E2E** internal-rule: services/backend/tests/integration/gates.test.ts

### Requirement: Lint suppressions carry a description
A service's lint SHALL fail on an inline suppression without a description and on an unused one.

#### Scenario: [service-checks-d62714] A bare suppression fails lint
- **WHEN** a file disables a rule inline with no description, or disables a rule that does not fire
- **THEN** `bun run lint` exits nonzero
- **NO E2E** internal-rule: services/backend/tests/integration/gates.test.ts

### Requirement: Tests contain behavioral assertions
A service's lint SHALL fail on a test whose callback has no direct completed assertion, or whose only assertions are snapshots.

#### Scenario: [service-checks-f37672] An assertion-free test fails lint
- **WHEN** a test callback under `tests/` makes no assertion, or only creates an `expect` it never completes
- **THEN** `bun run lint` exits nonzero naming the test
- **NO E2E** internal-rule: services/backend/tests/unit/test-policy.test.ts

#### Scenario: [service-checks-1a0230] A snapshot-only test fails lint
- **WHEN** a test callback's only assertion is a snapshot matcher
- **THEN** `bun run lint` exits nonzero naming the test
- **NO E2E** internal-rule: services/backend/tests/unit/test-policy.test.ts

#### Scenario: [service-checks-b489e4] A behavioral assertion permits a supplemental snapshot
- **WHEN** a test callback makes a behavioral assertion and also matches a snapshot
- **THEN** the test policy reports nothing for it
- **NO E2E** internal-rule: services/backend/tests/unit/test-policy.test.ts

### Requirement: Lint limits the complexity and size of code
A service's lint SHALL fail on a function over complexity 10, depth 3, 3 parameters or 50 lines, or a file over 300 lines, with looser limits for tests and components.

#### Scenario: [service-checks-ec3fd1] Code over a limit fails lint
- **WHEN** a source function has complexity 11 or 4 parameters
- **THEN** `bun run lint` exits nonzero naming the rule
- **NO E2E** internal-rule: services/backend/tests/integration/lint-limits.test.ts

#### Scenario: [service-checks-82af3e] Tests take the looser limits
- **WHEN** a test file has a 4-parameter helper and a callback over 50 lines
- **THEN** `bun run lint` reports neither
- **NO E2E** internal-rule: services/backend/tests/integration/lint-limits.test.ts

### Requirement: Every linted service sets the same limits
Every service's lint configuration SHALL carry the same lint-limits block.

#### Scenario: [service-checks-b1556d] The limits block is identical across services
- **WHEN** `bin/tests/lint-limits.test.sh` compares the lint-limits blocks of every service's `eslint.config.mjs`
- **THEN** they are byte-identical and the test passes

### Requirement: Coverage is complete
A service's `coverage` script SHALL fail unless every source module under `src/` appears in the report with 100% of its lines and functions covered.

#### Scenario: [service-checks-0a7378] Fully covered source passes
- **WHEN** both suites pass and the report covers every line and function of every `src/` module
- **THEN** `bun run coverage` exits 0
- **NO E2E** internal-rule: services/backend/tests/unit/coverage-report.test.ts

#### Scenario: [service-checks-3c1469] An uncovered line or function fails
- **WHEN** a `src/` module has one uncovered line or function
- **THEN** `bun run coverage` exits nonzero naming the module
- **NO E2E** internal-rule: services/backend/tests/unit/coverage-report.test.ts

#### Scenario: [service-checks-cdc6fa] A missing module or report fails
- **WHEN** a `src/` module is absent from the report, or the report is missing, empty or truncated
- **THEN** `bun run coverage` exits nonzero saying which
- **NO E2E** internal-rule: services/backend/tests/unit/coverage-report.test.ts

### Requirement: Coverage runs each suite once across workers
A service's `coverage` script SHALL run the unit and integration suites once, in as many parallel workers as `FACTORY_JOBS` allows, and fail when either suite has no test file.

#### Scenario: [service-checks-db3dcd] Workers follow the job count
- **WHEN** `bun run coverage` runs with `FACTORY_JOBS=2`
- **THEN** the tests run in at most 2 workers and produce one report
- **NO E2E** internal-rule: services/backend/tests/unit/coverage-report.test.ts

### Requirement: A service builds a checks and a runtime image
A service's Dockerfile SHALL have a `checks` target with frozen development dependencies and a `runtime` target that runs as a non-root user and carries no development dependencies: a server installs production dependencies only, a static site copies only its built files onto a web server image.

#### Scenario: [service-checks-5897ce] The two targets differ
- **WHEN** a service's Dockerfile is read
- **THEN** it has a `checks` target that installs with `--frozen-lockfile`, and a `runtime` target that installs with `--production` and sets a non-root `USER`

#### Scenario: [service-checks-44a61a] A static site's runtime serves only its build
- **WHEN** the ui's Dockerfile is read
- **THEN** its `runtime` target is the last stage, starts from a pinned unprivileged nginx image, installs nothing and copies only the built app, the Storybook build and its nginx configuration

### Requirement: The backend answers its health endpoint
The backend SHALL answer `GET /health` with status 200 and `{"ok":true}` while it can serve.

#### Scenario: [service-checks-7707f9] The health endpoint answers
- **WHEN** a client requests `GET /health` from a running backend
- **THEN** the response is 200 with the JSON body `{"ok":true}`

### Requirement: The backend answers GraphQL at /graphql
The backend SHALL answer GraphQL over `POST /graphql`, its schema starting with the `health` query.

#### Scenario: [service-checks-b99553] The health query answers
- **WHEN** a client posts `{ health { ok } }` to `/graphql` on a running backend
- **THEN** the response is 200 with `{"data":{"health":{"ok":true}}}`

### Requirement: The backend refuses invalid configuration
The backend SHALL validate its environment at startup and exit nonzero, naming each invalid variable, before it listens.

#### Scenario: [service-checks-836a90] An invalid port stops startup
- **WHEN** the backend starts with `PORT=abc`
- **THEN** it exits nonzero, the error names `PORT`, and nothing listens
- **NO E2E** internal-rule: services/backend/tests/unit/config.test.ts

### Requirement: bin/check runs a service's gates in its checks container
`bin/check <service>` SHALL build the service's `checks` target and run its lint, typecheck, coverage, duplicates, unused and imports scripts in one container from it, at the same time.

#### Scenario: [service-checks-a4a0e9] Every gate runs in the container
- **WHEN** `bin/check backend` runs
- **THEN** it builds `services/backend`'s `checks` target, runs `bun run lint`, `bun run typecheck`, `bun run coverage`, `bun run duplicates`, `bun run unused` and `bun run imports` in one container from it, and exits 0 when all six pass

#### Scenario: [service-checks-df8cd7] Each suite runs once per check
- **WHEN** `bin/check backend` runs
- **THEN** no `test:unit` or `test:integration` script runs besides `coverage`

### Requirement: bin/check validates its input before Docker
`bin/check` SHALL print its usage on `--help`, and exit 2 on no service, an unknown or unsafe service name, or a service named twice, before calling Docker.

#### Scenario: [service-checks-086fa5] Help and invalid input are local
- **WHEN** `bin/check` runs with `--help`, with no argument, with `../bin` or with a name that is not a service folder
- **THEN** it prints usage (exit 0 for `--help`, 2 otherwise) and Docker is never called

### Requirement: bin/check reports every failing gate
`bin/check` SHALL let every gate finish when one fails, then name each failed gate with its log and exit nonzero.

#### Scenario: [service-checks-247a01] Two failing gates are both named
- **WHEN** lint and coverage fail while typecheck passes
- **THEN** typecheck still runs to the end, the output names lint and coverage each with the path of its log, and the command exits nonzero

#### Scenario: [service-checks-4d1428] A failed build stops the check
- **WHEN** building the checks image fails
- **THEN** no gate runs, the output names the build step and its log, and the command exits nonzero

### Requirement: Each gate's lines are prefixed and logged
`bin/check` SHALL print every line a gate writes prefixed `<service>/<gate> | `, and keep that gate's own output in `<gate>.log` in the run's folder under `tmp/check/<service>/`.

#### Scenario: [service-checks-58493f] Every line names its gate
- **WHEN** the lint gate prints two lines
- **THEN** both appear prefixed `backend/lint | `, and `lint.log` in the run's folder holds them unprefixed

### Requirement: bin/check --gates runs only the named gates
`bin/check --gates <list>` SHALL run only the gates named in the comma-separated list, and exit 2 before Docker on an unknown, empty or repeated selection.

#### Scenario: [service-checks-680c1f] Selected gates run alone
- **WHEN** `bin/check backend --gates typecheck` runs
- **THEN** only `bun run typecheck` runs in the container and no coverage report is collected

#### Scenario: [service-checks-a10223] An invalid gate selection is local
- **WHEN** `bin/check backend --gates typecheck,,lint` or `--gates bogus` runs
- **THEN** it exits 2 with usage and Docker is never called

### Requirement: bin/check checks several services at once
`bin/check <service> <service>...` and `bin/check --all` SHALL check each service in its own `bin/check` at the same time, `--all` taking every service whose Dockerfile has a `checks` target.

#### Scenario: [service-checks-bc70aa] Named services run together
- **WHEN** `bin/check` runs with two service names
- **THEN** both services' checks run at the same time and the run ends with one `<service>: passed` or `<service>: failed` line each, in the order given

#### Scenario: [service-checks-f54ace] All services with a checks target
- **WHEN** `bin/check --all` runs
- **THEN** it checks every service whose Dockerfile has a `checks` target and no other

### Requirement: A failed service does not stop the others
When several services are checked, `bin/check` SHALL let every service's check finish and exit nonzero when any failed.

#### Scenario: [service-checks-28e346] One failed service fails the run
- **WHEN** two services are checked and the first fails
- **THEN** the second still runs to the end, the summary marks the first failed and the second passed, and the command exits nonzero

### Requirement: FACTORY_JOBS sets how many jobs the checks use
`bin/check` SHALL take its job count from an exported `FACTORY_JOBS`, else a `FACTORY_JOBS=<n>` line in `~/.factory/env`, else the machine's cores, and split it evenly across the services it checks.

#### Scenario: [service-checks-60d1b5] Unset means every core
- **WHEN** `FACTORY_JOBS` is neither exported nor in `~/.factory/env`
- **THEN** the container receives `FACTORY_JOBS` equal to the machine's core count

#### Scenario: [service-checks-f382dc] The machine env file caps every worktree
- **WHEN** `~/.factory/env` holds `FACTORY_JOBS=2` and nothing is exported
- **THEN** the container receives `FACTORY_JOBS=2`

#### Scenario: [service-checks-78a9b1] Several services share the jobs
- **WHEN** `FACTORY_JOBS=4` and two services are checked
- **THEN** each service's container receives `FACTORY_JOBS=2`

### Requirement: An invalid FACTORY_JOBS fails before Docker
`bin/check` SHALL exit nonzero, naming `FACTORY_JOBS`, when its value is not a positive integer, before calling Docker.

#### Scenario: [service-checks-ea3bad] An invalid job count is rejected
- **WHEN** `FACTORY_JOBS=0` or `FACTORY_JOBS=two` is exported
- **THEN** `bin/check backend` exits nonzero naming `FACTORY_JOBS` and Docker is never called

### Requirement: Check resources are invocation-local
Each `bin/check` run SHALL use its own image tag, container name and output folder, and remove its image and container on exit, failing when removal fails.

#### Scenario: [service-checks-e7ab77] Concurrent runs are isolated
- **WHEN** two `bin/check backend` runs overlap
- **THEN** they use different image tags, container names and run folders, and each removes only its own image and container

#### Scenario: [service-checks-28396e] A missing coverage report is visible
- **WHEN** coverage passes but the container holds no `coverage/lcov.info`
- **THEN** `bin/check` exits nonzero saying the report is missing

### Requirement: The check commands describe themselves
`bin/check --help` SHALL describe the gates, `--gates`, `--all`, `FACTORY_JOBS` and where logs and coverage are kept.

#### Scenario: [service-checks-6ccbef] Help names the gates and the job setting
- **WHEN** `bin/check --help` runs
- **THEN** its output names lint, typecheck, coverage, duplicates, unused, imports, `--gates`, `--all`, `FACTORY_JOBS` and `tmp/check/`

### Requirement: The backend's health reports its database
The backend's `GET /health` SHALL answer 503 with `{"ok":false}` when the database cannot be reached.

#### Scenario: [service-checks-1b899c] An unreachable database fails the health check
- **WHEN** a client requests `GET /health` while the backend cannot reach the database
- **THEN** the response is 503 with the JSON body `{"ok":false}`
- **NO E2E** internal-rule: services/backend/tests/integration/health.test.ts

### Requirement: bin/check runs the contracts gate first
`bin/check` SHALL run the `contracts` gate alone before the other gates, and stop without running them when it fails.

#### Scenario: [service-checks-31b834] A stale contract stops the check
- **WHEN** `bin/check backend` runs and `bun run contracts` fails
- **THEN** lint, typecheck and coverage do not run, the output names the contracts gate and its log, and the command exits nonzero

#### Scenario: [service-checks-39fb15] Contracts precede the other gates
- **WHEN** `bin/check backend` runs and every gate passes
- **THEN** `bun run contracts` finishes before lint, typecheck and coverage start

### Requirement: A UI page never imports another page
The ui's lint SHALL reject an import from one `src/pages/<name>/` folder into another.

#### Scenario: [service-checks-07c2e1] A cross-page import fails lint
- **WHEN** a module under `src/pages/home/` imports a module under `src/pages/not-found/`
- **THEN** `bun run lint` exits nonzero naming the import
- **NO E2E** internal-rule: services/ui/tests/integration/lint-rules.test.ts

### Requirement: UI strings use known translation keys
The ui's typecheck SHALL reject a translation key that the English locale does not define.

#### Scenario: [service-checks-0e451e] An unknown key fails the typecheck
- **WHEN** a component calls `t("no.such.key")`
- **THEN** `bun run typecheck` exits nonzero naming the file
- **NO E2E** internal-rule: services/ui/tests/integration/i18n-keys.test.ts

### Requirement: Every UI translation key is used
The ui's tests SHALL fail on a key in the English locale that no source file uses.

#### Scenario: [service-checks-6a91cd] An unused key fails the tests
- **WHEN** `src/i18n/locales/en/common.json` holds a key no file under `src/` references
- **THEN** `bun run test:integration` fails naming the key
- **NO E2E** internal-rule: services/ui/tests/integration/i18n-keys.test.ts

### Requirement: The backend allows its UI's origin
The backend SHALL answer a request from the origin in `APP_URL` with `Access-Control-Allow-Origin` set to that origin and `Access-Control-Allow-Credentials: true`.

#### Scenario: [service-checks-2900a9] The UI's origin is allowed
- **WHEN** a request to `/graphql` carries `Origin` equal to `APP_URL`
- **THEN** the response carries `Access-Control-Allow-Origin: <APP_URL>`, `Access-Control-Allow-Credentials: true` and `Vary: Origin`

### Requirement: The backend refuses CORS to other origins
The backend SHALL send no CORS header in answer to a request from an origin other than `APP_URL`.

#### Scenario: [service-checks-3e0690] Another origin gets no CORS header
- **WHEN** a request to `/graphql` carries `Origin: http://elsewhere.test`
- **THEN** the response has no `Access-Control-Allow-Origin` header

### Requirement: The backend answers the UI's preflight
The backend SHALL answer an `OPTIONS` preflight from `APP_URL` with 204, allowing `GET` and `POST`, the `Content-Type` header and a max age of 600 seconds.

#### Scenario: [service-checks-02099e] A preflight from the UI succeeds
- **WHEN** an `OPTIONS` request to `/graphql` carries `Origin` equal to `APP_URL`
- **THEN** it answers 204 with `Access-Control-Allow-Methods: GET, POST`, `Access-Control-Allow-Headers: Content-Type` and `Access-Control-Max-Age: 600`

### Requirement: The backend requires its UI's origin
The backend SHALL refuse to start when `APP_URL` is missing or not a bare http(s) origin, naming the variable.

#### Scenario: [service-checks-8ab0f6] An invalid APP_URL stops startup
- **WHEN** the backend starts with `APP_URL` unset, or set to `http://user:pw@ui.test/path`
- **THEN** it exits nonzero, the error names `APP_URL` and not its value, and nothing listens
- **NO E2E** internal-rule: services/backend/tests/unit/config.test.ts

### Requirement: Copied code fails the duplicates gate
A service's `duplicates` gate SHALL fail when a block of at least 50 tokens and 5 lines appears twice in its `src/`, `tests/` or `tooling/` code, naming the file and lines of both copies and how to fix it.

#### Scenario: [service-checks-7cc7ba] A copied block fails
- **WHEN** a service has the same block of 50 tokens and 5 lines in two of its code files
- **THEN** `bun run duplicates` exits nonzero, its output names both files with their line ranges, and says to extract the shared code or mark the clone and raise the baseline
- **NO E2E** internal-rule: services/backend/tests/integration/structure-gates.test.ts

#### Scenario: [service-checks-63937c] Generated code is not compared
- **WHEN** the only copy of a block is in generated code (`contracts/` or a `generated/` folder)
- **THEN** `bun run duplicates` exits 0
- **NO E2E** internal-rule: services/backend/tests/integration/structure-gates.test.ts

#### Scenario: [service-checks-b4b48e] A marked clone passes
- **WHEN** one copy of a block is wrapped in `jscpd:ignore-start` and `jscpd:ignore-end` comments
- **THEN** `bun run duplicates` exits 0
- **NO E2E** internal-rule: services/backend/tests/integration/structure-gates.test.ts

### Requirement: Every service sets the same duplication rules
Every service with a checks target SHALL carry a duplication configuration identical to every other service's.

#### Scenario: [service-checks-c5bf46] The duplication settings are identical across services
- **WHEN** `bin/tests/structure-config.test.sh` compares every service's duplication configuration
- **THEN** the test fails when one differs from backend's or a service with a checks target has none, and passes otherwise

### Requirement: Unused code fails the unused gate
A service's `unused` gate SHALL fail on an unused file, export, exported type, dependency or devDependency, or an import of an unlisted dependency, naming where it is and how to fix it.

#### Scenario: [service-checks-d169b4] An unused export fails
- **WHEN** a `src/` module exports a function that no other file imports
- **THEN** `bun run unused` exits nonzero, names the export with its file and line, and says to delete or unexport it, or mark it `knipignore` and raise the baseline
- **NO E2E** internal-rule: services/backend/tests/integration/structure-gates.test.ts

#### Scenario: [service-checks-976eee] An unused file fails
- **WHEN** a `src/` file is reached from no entry point
- **THEN** `bun run unused` exits nonzero naming the file
- **NO E2E** internal-rule: services/backend/tests/integration/structure-gates.test.ts

#### Scenario: [service-checks-52637d] An unused dependency fails
- **WHEN** `package.json` lists a dependency that no code, script or tool configuration uses
- **THEN** `bun run unused` exits nonzero naming the dependency and its `package.json` line
- **NO E2E** internal-rule: services/backend/tests/integration/structure-gates.test.ts

#### Scenario: [service-checks-3f992d] A marked export passes
- **WHEN** an otherwise unused export carries a `@knipignore` tag
- **THEN** `bun run unused` does not report it
- **NO E2E** internal-rule: services/backend/tests/integration/structure-gates.test.ts

### Requirement: Every service sets the same unused-code rules
Every service with a checks target SHALL carry an unused-code rules block identical to every other service's.

#### Scenario: [service-checks-09dab7] The unused-code rules are identical across services
- **WHEN** `bin/tests/structure-config.test.sh` compares every service's unused-code rules block
- **THEN** the test fails when one differs from backend's or a service with a checks target has none, and passes otherwise

### Requirement: Import cycles fail the imports gate
A service's `imports` gate SHALL fail when its modules import each other in a cycle, naming every module of the cycle and how to fix it.

#### Scenario: [service-checks-21ca49] A cycle fails
- **WHEN** two `src/` modules import each other
- **THEN** `bun run imports` exits nonzero, names both modules and the cycle rule, and says to move the shared part into a module both import
- **NO E2E** internal-rule: services/backend/tests/integration/structure-gates.test.ts

### Requirement: Layer violations fail the imports gate
A service's `imports` gate SHALL fail on an import its layer rules forbid, naming the importing file, the imported file, the rule and how to fix it.

#### Scenario: [service-checks-289d62] A backend resolver importing the database fails
- **WHEN** a backend module under `src/graphql/` imports a module under `src/db/`
- **THEN** `bun run imports` exits nonzero naming both files and the rule, which says to reach data through a domain module
- **NO E2E** internal-rule: services/backend/tests/integration/structure-gates.test.ts

#### Scenario: [service-checks-6bfd61] A ui component importing a service fails
- **WHEN** a ui module under `src/components/` imports a module under `src/services/`
- **THEN** `bun run imports` exits nonzero naming both files and the rule, which says to go through a hook
- **NO E2E** internal-rule: services/ui/tests/integration/structure-gates.test.ts

#### Scenario: [service-checks-9ff7b9] Stories are exempt from ui layer rules
- **WHEN** a `*.stories.tsx` file under `src/components/` imports a module under `src/services/`
- **THEN** `bun run imports` does not report it
- **NO E2E** internal-rule: services/ui/tests/integration/structure-gates.test.ts

### Requirement: Every service sets the same shared import rules
Every service with a checks target SHALL carry a shared import rules block identical to every other service's.

#### Scenario: [service-checks-396ebd] The shared import rules are identical across services
- **WHEN** `bin/tests/structure-config.test.sh` compares every service's shared import rules block
- **THEN** the test fails when one differs from backend's or a service with a checks target has none, and passes otherwise

### Requirement: Mutation testing covers a service with a mutate target
`bin/mutate` SHALL refuse a service whose Dockerfile has no `mutate` target, or an unknown service, before building anything; `backend` and `ui` have one, `e2e` does not.

#### Scenario: [service-checks-37bce9] A service without mutation testing is refused
- **WHEN** `bin/mutate` is given a service with no `mutate` target, or a name that is not a service
- **THEN** it fails with a message naming the service, before Docker runs

### Requirement: A full mutation run reports the score
`bin/mutate <service>` without `--changed` SHALL mutate the service's whole source, print the score and every surviving or uncovered mutant, and fail only when the mutation tool itself fails.

#### Scenario: [service-checks-748bc5] A full run reports survivors without failing
- **WHEN** `bin/mutate backend` runs on source where some mutants survive
- **THEN** it prints the score and each survivor, ends with `backend: passed`, and exits 0

### Requirement: Every mutation run keeps its reports
Every `bin/mutate` run SHALL keep its JSON and HTML reports and a markdown summary in a new folder under `tmp/mutate/<service>/`, print that folder, and end with `<service>: passed` or `<service>: failed`, whether it passed or failed.

#### Scenario: [service-checks-b71438] A run's reports are kept in a new folder
- **WHEN** `bin/mutate` runs, passing or failing
- **THEN** it prints `Reports: <folder>`, a folder under `tmp/mutate/<service>/` no earlier run used, holding `mutation.json`, `mutation.html` and `summary.md`

### Requirement: Changed code can be mutation tested
`bin/mutate <service> --changed` SHALL mutate only the source lines the branch adds or changes against its base (the merge base with `origin/main`, or `--base <ref>`), committed or not, and fail when any mutant survives or no test covers it, printing each one's file, line, mutator, and original and mutated code; a timed-out mutant counts as killed.

#### Scenario: [service-checks-d0f5a5] A surviving mutant fails the changed run
- **WHEN** a branch changes a line of `backend` that no test notices being mutated, and `bin/mutate backend --changed` runs
- **THEN** it fails and prints the mutant's file, line, mutator, and original and mutated code

#### Scenario: [service-checks-a16f43] An uncovered mutant fails the changed run
- **WHEN** a branch adds a line of `backend` that no unit or integration test runs, and `bin/mutate backend --changed` runs
- **THEN** it fails and names the mutant as not covered

#### Scenario: [service-checks-e1c617] Killed mutants pass the changed run
- **WHEN** every mutant of the branch's changed lines is killed by a test or times out
- **THEN** `bin/mutate backend --changed` passes and prints the score

#### Scenario: [service-checks-a98197] No changed source skips the run
- **WHEN** a branch changes no source line of the service, or only deletes lines, and `bin/mutate <service> --changed` runs
- **THEN** it prints `Nothing to mutate.` and passes without starting Docker

### Requirement: Thrown error texts are not mutated
Mutation testing SHALL NOT mutate the message text passed to a constructed `Error` or Error subclass, nor the `name` an Error subclass assigns; every other string, including texts a client receives, is mutated.

#### Scenario: [service-checks-3695c6] Error message text is skipped
- **WHEN** a mutated line throws `new Error("...")` with a literal message, or an Error subclass assigns its `name`
- **THEN** the mutation run creates no string mutant for that text

#### Scenario: [service-checks-c589e9] Client-visible text is still mutated
- **WHEN** a mutated line returns a literal string, outside an Error constructor
- **THEN** the mutation run mutates that string

### Requirement: Schema definition settings are not mutated
Mutation testing SHALL NOT mutate the settings of a GraphQL schema definition inside a call on the schema `builder`, such as a field's description, nullability or type. A function that runs per request, such as a field's `resolve`, is mutated with its code and every node around it.

#### Scenario: [service-checks-60d662] A field's settings are skipped
- **WHEN** a mutated line of `backend` sets a field's description inside a `builder` call
- **THEN** the mutation run creates no mutant for that description

#### Scenario: [service-checks-509f55] Resolver code is still mutated
- **WHEN** a mutated line of `backend` compares values inside a field's `resolve` function
- **THEN** the mutation run mutates that comparison

### Requirement: Class name strings are not mutated
Mutation testing of `ui` SHALL NOT create string mutants of a `className` attribute's text, of the arguments of `cn(...)` and `cva(...)`, or of a `cva` variant's classes; the conditions that pick a class, and every other string, are mutated.

#### Scenario: [service-checks-e5eec4] Class names are skipped and rendered text is not
- **WHEN** a mutated `ui` component sets `className="..."`, passes classes to `cn(...)` under a condition, and renders a literal text
- **THEN** the mutation run creates no string mutant for the classes, and does mutate the condition and the rendered text

### Requirement: A mutation run's first test run may take 15 minutes
The mutation run SHALL allow its first full run of the unit and integration tests 15 minutes before giving up.

#### Scenario: [service-checks-c6a129] The first test run's limit
- **WHEN** `bin/mutate` starts a run for `backend` or `ui`
- **THEN** Stryker allows the first test run 15 minutes
- **NO E2E** internal-rule: each service's Stryker config allows the first test run 15 minutes; services/backend/tests/unit/stryker-config.test.ts

### Requirement: Only application source is mutated
`bin/mutate` SHALL NOT mutate generated code, migrations, stories, tests, tooling or a service's entry module (`src/index.ts`, `src/main.tsx`), which starts the app when imported: only a service's application source under `src/`.

#### Scenario: [service-checks-b6ed25] Generated code, migrations, stories and entry modules are skipped
- **WHEN** a branch changes a line under `src/` of generated code, a migration, a story or the entry module, and `bin/mutate <service> --changed` runs
- **THEN** the mutation run creates no mutant for that line
- **NO E2E** internal-rule: each service's mutation scope leaves them out; services/ui/tests/unit/mutation-report.test.ts

### Requirement: bin/check runs the gates with no network
`bin/check` SHALL run a service's gates in a container with no network beyond loopback, while building the checks image keeps its network.

#### Scenario: [service-checks-172a37] A gate that stays offline passes
- **WHEN** `bin/check backend` runs and no test reaches beyond loopback
- **THEN** the gates run in a container created with no network, every gate passes, no network line is printed, and the command exits 0

### Requirement: bin/check names a gate that reached for the network
When a gate fails and its log shows a network error (`EAI_AGAIN`, `ENETUNREACH` or `EHOSTUNREACH`), `bin/check` SHALL print, after naming the failed gate, that the gate tried to reach the network, that checks run with no network on purpose, and to fake the provider at its contract.

#### Scenario: [service-checks-5ed7ca] A gate that reaches the network fails with the reason
- **WHEN** `bin/check backend` runs and a test in the coverage gate fetches a public URL
- **THEN** the coverage gate fails, the output names it with its log and prints `backend: coverage tried to reach the network; checks run with no network on purpose: fake the provider at its contract`, and the command exits nonzero
