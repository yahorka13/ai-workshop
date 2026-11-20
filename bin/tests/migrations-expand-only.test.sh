# shellcheck shell=bash disable=SC2154
# bin/check-migrations-expand-only.sh

gate() { "$BIN/check-migrations-expand-only.sh" "$@"; }

# A fake repository root: the gate scans every service that owns migrations.
migration() {
  mkdir -p "root/services/backend/src/db/migrations/$1"
  printf '%s\n' "$2" > "root/services/backend/src/db/migrations/$1/migration.sql"
}

# [database-e1f727]
test_database_e1f727_destructive_statements_are_rejected_naming_file_and_line() {
  while read -r statement; do
    rm -rf root
    migration 20261016120000_change "$statement"
    expect_fail gate root
    expect_output "20261016120000_change/migration.sql:1:"
    expect_output "$statement"
  done <<'STATEMENTS'
DROP TABLE "contacts";
ALTER TABLE "contacts" DROP COLUMN "name";
ALTER TABLE "contacts" RENAME TO "people";
ALTER TABLE "contacts" RENAME COLUMN "name" TO "title";
ALTER TABLE "contacts" ALTER COLUMN "name" TYPE varchar(10);
ALTER TABLE "contacts" ALTER COLUMN "name" SET DATA TYPE varchar(10);
ALTER TABLE "contacts" ALTER COLUMN "name" SET NOT NULL;
DROP SCHEMA "public";
TRUNCATE "contacts";
STATEMENTS
}

# [database-e79e4f]
test_database_e79e4f_a_declared_contract_step_passes() {
  migration 20261016120000_change '-- contract: name was expanded in 20261015192638_initial and backfilled
ALTER TABLE "contacts" DROP COLUMN "name";'
  expect_pass gate root
  expect_output "contract step"
}

# [database-136db4]
test_database_136db4_a_committed_push_is_rejected() {
  migration 20261015192638_initial 'CREATE TABLE "contacts" ("id" uuid PRIMARY KEY NOT NULL);'
  mkdir -p root/.github/workflows
  printf '{\n  "scripts": { "db:push": "bun --bun drizzle-kit push" }\n}\n' > root/services/backend/package.json
  expect_fail gate root
  expect_output "package.json"
  expect_output "push"
}

test_a_push_in_a_workflow_is_rejected() {
  migration 20261015192638_initial 'CREATE TABLE "contacts" ("id" uuid PRIMARY KEY NOT NULL);'
  mkdir -p root/.github/workflows
  printf 'jobs:\n  deploy:\n    steps:\n      - run: bun --bun drizzle-kit push\n' > root/.github/workflows/deploy.yml
  expect_fail gate root
  expect_output "deploy.yml"
}

test_additive_migrations_pass() {
  migration 20261015192638_initial 'CREATE TABLE "contacts" (
	"id" uuid PRIMARY KEY NOT NULL,
	"name" text NOT NULL
);
--> statement-breakpoint
ALTER TABLE "contacts" ADD COLUMN "timezone" text;
--> statement-breakpoint
CREATE INDEX "contacts_name" ON "contacts" ("name");'
  expect_pass gate root
}

# [database-d082c3]
test_database_d082c3_a_destructive_word_inside_a_comment_or_string_passes() {
  migration 20261016120500_notes '-- We never drop table contacts here; the rename happens in a later release.
INSERT INTO "contacts" ("id", "name") VALUES (gen_random_uuid(), '"'"'Drop Table Inc'"'"');'
  expect_pass gate root
}

test_an_empty_or_missing_migrations_folder_passes() {
  mkdir -p root/services/backend/src/db/migrations
  expect_pass gate root
  rm -rf root/services
  expect_pass gate root
}

test_the_real_repository_passes() {
  expect_pass gate "$ROOT"
}

# [database-4ac69d]
test_database_4ac69d_help_and_argument_handling() {
  expect_pass gate --help
  expect_output "usage: bin/check-migrations-expand-only.sh"
  expect_fail gate one two
}

test_a_destructive_statement_is_named_by_its_own_line() {
  migration 20261016120000_change 'ALTER TABLE "contacts" ADD COLUMN "phones" text[];
ALTER TABLE "contacts" ALTER COLUMN "phone" SET DEFAULT '"'"'none'"'"';
ALTER TABLE "contacts" DROP COLUMN "phone";'
  expect_fail gate root
  expect_output '20261016120000_change/migration.sql:3: not backward-compatible: ALTER TABLE "contacts" DROP COLUMN "phone";'
}

test_a_new_column_default_passes() {
  migration 20261016120000_change 'ALTER TABLE "contacts" ALTER COLUMN "phone" SET DEFAULT '"'"'none'"'"';'
  expect_pass gate root
}
