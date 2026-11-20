# shellcheck shell=bash disable=SC2154
# bin/check-migrations-immutable.sh

gate() { "$BIN/check-migrations-immutable.sh" "$@"; }
folder=services/backend/src/db/migrations
initial="$folder/20261015192638_initial"

# A base commit holding one applied migration folder: its SQL and snapshot.
applied() {
  mkdir -p "$initial"
  printf 'CREATE TABLE "contacts" ();\n' > "$initial/migration.sql"
  printf '{\n  "tables": {}\n}\n' > "$initial/snapshot.json"
  git add "$folder"
  git commit -q -m "[1] Apply the initial migration"
  git tag base
}

committed() {
  git add -A
  git commit -q -m "[1] Change the migrations"
}

# [database-50d7ba]
test_database_50d7ba_editing_an_applied_migration_is_rejected() {
  applied
  printf 'CREATE TABLE "contacts" ();\nALTER TABLE "contacts" ADD COLUMN "name" text;\n' > "$initial/migration.sql"
  committed
  expect_fail gate base HEAD
  expect_output "20261015192638_initial/migration.sql"
  expect_output "already applied"
}

test_deleting_an_applied_migration_is_rejected() {
  applied
  rm -r "$initial"
  committed
  expect_fail gate base HEAD
  expect_output "20261015192638_initial/migration.sql"
}

test_editing_an_applied_snapshot_is_rejected() {
  applied
  printf '{\n  "tables": { "public.contacts": {} }\n}\n' > "$initial/snapshot.json"
  committed
  expect_fail gate base HEAD
  expect_output "20261015192638_initial/snapshot.json"
}

# [database-396e34]
test_database_396e34_adding_a_migration_is_accepted() {
  applied
  mkdir -p "$folder/20261016121500_name"
  printf 'ALTER TABLE "contacts" ADD COLUMN "name" text;\n' > "$folder/20261016121500_name/migration.sql"
  printf '{\n  "tables": { "public.contacts": {} }\n}\n' > "$folder/20261016121500_name/snapshot.json"
  committed
  expect_pass gate base HEAD
}

# The next migration folder with the given snapshot, the previous one deleted,
# as bun run db:generate leaves them.
next_migration() {
  mkdir -p "$folder/20261016121500_name"
  printf 'ALTER TABLE "contacts" ADD COLUMN "name" text;\n' > "$folder/20261016121500_name/migration.sql"
  printf '%s' "$1" > "$folder/20261016121500_name/snapshot.json"
  rm "$initial/snapshot.json"
}

# [database-175fbc]
test_database_175fbc_deleting_an_older_snapshot_is_accepted() {
  applied
  next_migration $'{\n  "tables": { "public.contacts": { "columns": { "name": {} } } },\n  "views": {}\n}\n'
  committed
  expect_pass gate base HEAD
}

test_a_snapshot_seen_as_renamed_is_accepted() {
  applied
  # Identical content, so git reports the pair as a rename.
  next_migration $'{\n  "tables": {}\n}\n'
  committed
  git diff --name-status --find-renames base HEAD | grep -q '^R.*snapshot.json' || fail 'git did not see a rename'
  expect_pass gate base HEAD
}

test_deleting_a_snapshot_without_a_newer_one_is_rejected() {
  applied
  rm "$initial/snapshot.json"
  committed
  expect_fail gate base HEAD
  expect_output "20261015192638_initial/snapshot.json"
}

test_a_renamed_applied_migration_is_rejected() {
  applied
  git mv "$initial" "$folder/20261015192638_renamed"
  committed
  expect_fail gate base HEAD
}

test_changes_outside_the_migrations_folder_are_ignored() {
  applied
  printf 'export const value = 1;\n' > services/backend/src/other.ts
  committed
  expect_pass gate base HEAD
}

test_a_module_beside_the_migrations_folder_is_ignored() {
  applied
  printf 'export const run = 1;\n' > services/backend/src/db/migrations.ts
  git add services/backend/src/db/migrations.ts
  git commit -q -m "[1] Add the migration runner"
  git tag -f base > /dev/null
  printf 'export const run = 2;\n' > services/backend/src/db/migrations.ts
  committed
  expect_pass gate base HEAD
  printf 'CREATE TABLE "contacts" ("id" uuid);\n' > "$initial/migration.sql"
  committed
  expect_fail gate base HEAD
  expect_output "20261015192638_initial/migration.sql"
}

test_no_migrations_at_all_passes() {
  git commit -q --allow-empty -m "[1] Nothing to do"
  expect_pass gate HEAD~1 HEAD
}

# [database-4ac69d]
test_database_4ac69d_help_and_argument_handling() {
  expect_pass gate --help
  expect_output "usage: bin/check-migrations-immutable.sh"
  expect_fail gate
  expect_fail gate only-one
  expect_fail gate HEAD no-such-ref
  expect_output "Unknown ref: no-such-ref"
}
