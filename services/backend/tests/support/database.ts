// A real PostgreSQL engine in WebAssembly with the committed migration history
// applied, so tests run against the schema the stack runs.
import { PGlite } from "@electric-sql/pglite";
import { drizzle, type PgliteDatabase } from "drizzle-orm/pglite";
import { migrate } from "drizzle-orm/pglite/migrator";
import { MIGRATIONS } from "../../tooling/migrate";

export type TestDatabase = PgliteDatabase & { $client: PGlite };

/** A fresh database with every committed migration applied. */
export async function migratedDatabase(): Promise<TestDatabase> {
  const db = drizzle({ client: new PGlite() });
  await migrate(db, MIGRATIONS);
  return db;
}
