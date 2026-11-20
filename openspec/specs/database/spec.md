# database Specification

## Purpose
The database the backend owns: its one migration history, how migrations are generated from the schema, verified and applied, and the checks that keep the history expand-only and immutable.

## Requirements

### Requirement: Generated SQL is the committed migration
`bun run db:generate` SHALL write each migration as `src/db/migrations/<timestamp>_<name>/migration.sql`, generated from the schema module, for review and commit.

#### Scenario: [database-36f3ec] Generating a migration
- **WHEN** a table is added to the schema module and `bun run db:generate` runs
- **THEN** a new `<timestamp>_<name>/` folder holds a `migration.sql` that creates the table
- **NO E2E** internal-rule: services/backend/tests/integration/db-generate.test.ts

### Requirement: Only the newest migration keeps a snapshot
`bun run db:generate` SHALL leave a `snapshot.json` in the newest migration folder only.

#### Scenario: [database-811aa6] Generating keeps one snapshot
- **WHEN** `bun run db:generate` writes a second migration
- **THEN** the new folder holds a `snapshot.json` and the older folder no longer does
- **NO E2E** internal-rule: services/backend/tests/unit/snapshots.test.ts

### Requirement: The history is applied in order, each migration once
`bun run db:migrate` SHALL apply every committed migration not yet recorded, in folder-name order, and record each one.

#### Scenario: [database-14fedb] Applying to an empty database
- **WHEN** `bun run db:migrate` runs against an empty database with two committed migrations
- **THEN** both are applied in folder-name order and both are recorded

#### Scenario: [database-f98489] Re-running against a current database
- **WHEN** `bun run db:migrate` runs again against the same database
- **THEN** nothing is applied, nothing changes, and it exits 0

### Requirement: Migration runners do not interleave
`bun run db:migrate` SHALL hold a Postgres advisory lock while applying, so runners started together apply the history once.

#### Scenario: [database-76d7a6] Two runners started together
- **WHEN** two runners start at the same moment against the same empty database
- **THEN** both exit 0, each migration is applied and recorded once, and neither fails on the other's work

### Requirement: A failing migration is not recorded
When a migration fails, `bun run db:migrate` SHALL roll back every migration of that run, record none of them and exit nonzero.

#### Scenario: [database-129a02] A failing migration
- **WHEN** the second of two pending migrations fails
- **THEN** neither leaves a trace or is recorded, and the command exits nonzero quoting the failed statement

### Requirement: The migration command prints its usage
`bun run db:migrate --help` SHALL print its usage and exit 0 without connecting.

#### Scenario: [database-cd5777] Command usage
- **WHEN** `bun run db:migrate --help` runs with no database reachable
- **THEN** it prints its usage and exits 0

### Requirement: The backend applies the history before it serves
The backend's runtime image SHALL apply the migration history before it starts serving, and exit without serving when applying fails.

#### Scenario: [database-8919a7] A backend started against an empty database
- **WHEN** the runtime image starts against an empty database
- **THEN** every committed migration is recorded before `/health` first answers

#### Scenario: [database-bb83e6] An unreachable database stops startup
- **WHEN** the runtime image starts and the database cannot be reached
- **THEN** the container exits nonzero and nothing listens

### Requirement: The migration check finds a schema with no migration
`bun run db:verify` SHALL fail when the committed migrations no longer describe the schema module.

#### Scenario: [database-5b3ec0] A schema change with no migration
- **WHEN** the schema module gains a column and no migration is generated
- **THEN** `bun run db:verify` exits nonzero saying a migration is missing
- **NO E2E** internal-rule: services/backend/tests/integration/db-drift.test.ts

#### Scenario: [database-753cbf] A generated schema change passes
- **WHEN** the schema module gains a column and `bun run db:generate` has run
- **THEN** `bun run db:verify` exits 0
- **NO E2E** internal-rule: services/backend/tests/integration/db-drift.test.ts

### Requirement: The migration check verifies the folder layout
`bun run db:verify` SHALL fail on a migrations folder that is malformed or holds more than one snapshot.

#### Scenario: [database-513dca] A malformed migrations folder
- **WHEN** a migration folder lacks `migration.sql`, has a name that is not `<timestamp>_<name>`, or a second folder keeps a `snapshot.json`
- **THEN** `bun run db:verify` exits nonzero naming the folder
- **NO E2E** internal-rule: services/backend/tests/unit/db-migrations.test.ts

### Requirement: Migrations are expand-only unless marked
`bin/check-migrations-expand-only.sh` SHALL fail on a committed migration that drops, renames, retypes, truncates or adds NOT NULL to an existing column, unless it carries a `-- contract: <reason>` comment.

#### Scenario: [database-e1f727] A destructive migration fails
- **WHEN** a committed `migration.sql` holds `ALTER TABLE contacts DROP COLUMN phone;` with no contract comment
- **THEN** the check exits nonzero naming the file and line

#### Scenario: [database-e79e4f] A declared contract step passes
- **WHEN** the same migration starts with `-- contract: phone was expanded into phones and backfilled`
- **THEN** the check exits 0

#### Scenario: [database-d082c3] Comments and strings are not statements
- **WHEN** a migration mentions `DROP TABLE` only in a comment or a single-quoted string
- **THEN** the check exits 0

### Requirement: No committed live-database push
`bin/check-migrations-expand-only.sh` SHALL fail when a committed package script or workflow runs the schema tool's push command.

#### Scenario: [database-136db4] A committed push command
- **WHEN** a service's `package.json` has a script running `drizzle-kit push`
- **THEN** the check exits nonzero naming the file

### Requirement: Applied migrations are never edited
`bin/check-migrations-immutable.sh <base> <head>` SHALL fail when a migration that `<base>` contains is modified, deleted or renamed in `<head>`.

#### Scenario: [database-50d7ba] Editing a committed migration fails
- **WHEN** `<head>` changes one line of a `migration.sql` that `<base>` holds
- **THEN** the check exits nonzero naming the file

#### Scenario: [database-396e34] Adding a migration passes
- **WHEN** `<head>` only adds a new migration folder
- **THEN** the check exits 0

#### Scenario: [database-175fbc] Moving the snapshot forward passes
- **WHEN** `<head>` adds a migration folder with a `snapshot.json` and deletes the previous folder's `snapshot.json`
- **THEN** the check exits 0

### Requirement: The migration checks describe themselves
Each migration check script SHALL print its usage on `--help` and exit 2 on wrong arguments.

#### Scenario: [database-4ac69d] Help and wrong arguments
- **WHEN** either script runs with `--help`, then with too many arguments
- **THEN** it prints usage and exits 0, then exits 2
