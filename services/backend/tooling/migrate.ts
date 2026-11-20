// Apply the committed migration history.
//
// The driver is node-postgres, one of the two drivers Drizzle supports
// natively, so the query layer and this script speak the same documented
// dialect.
//
// drizzle-kit's own `migrate` command could now connect, and is deliberately
// not used: it is a development dependency, and pulling it plus its bundler
// into the production image (about 59 MB) only to apply migrations would mean
// either shipping a build toolchain to production or migrating from a
// different image than the one that serves. It also takes no lock — measured:
// two overlapping runs leave one of them failed. So this calls the migrator
// that ships with drizzle-orm, a runtime dependency, and adds that lock.
import { drizzle } from "drizzle-orm/node-postgres";
import { migrate } from "drizzle-orm/node-postgres/migrator";
import type { PoolClient } from "pg";
import { runCommand } from "../src/db/command";

const usage = `usage: bun run db:migrate
       bun run db:migrate --help

Apply every committed migration in src/db/migrations, in folder-name order and
exactly once, to the database POSTGRES_DB at POSTGRES_URL (postgres://<host>
[:<port>], no credentials), connecting as the owner POSTGRES_USER with
POSTGRES_PASSWORD. Applying an already-current database changes nothing.

An advisory lock is held while applying, so two runners started together
serialize instead of racing: drizzle's migrator takes no lock of its own.

Generate a migration with \`bun run db:generate\` after changing
src/db/schema, and commit the SQL it writes. There are no down migrations: every
migration has to be backward-compatible, so the previous image still runs
against the database the next one migrated.`;

// One fixed key for the whole history.
export const LOCK_KEY = 9_173_244_120_018;

export const MIGRATIONS = {
  migrationsFolder: "src/db/migrations",
  migrationsSchema: "drizzle",
  migrationsTable: "__drizzle_migrations",
} as const;

// Apply the history under the advisory lock.
async function applyHistory(client: PoolClient): Promise<void> {
  await client.query(`select pg_advisory_lock(${LOCK_KEY})`);
  try {
    await migrate(drizzle({ client }), MIGRATIONS);
    console.log("Migrations are up to date.");
  } finally {
    await client.query(`select pg_advisory_unlock(${LOCK_KEY})`);
    client.release();
  }
}

if (import.meta.main) {
  // One client from the pool: an advisory lock belongs to the session that
  // took it, so the lock and the migrations run on the same connection.
  process.exitCode = await runCommand(usage, async (pool) => {
    await applyHistory(await pool.connect());
  });
}
