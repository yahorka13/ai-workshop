import { expect, test } from "bun:test";
import { PGlite } from "@electric-sql/pglite";
import { drizzle } from "drizzle-orm/pglite";
import { migrate } from "drizzle-orm/pglite/migrator";
import { MIGRATIONS } from "../../tooling/migrate";
import { serviceRoot } from "../fixtures";

// PGlite is a real PostgreSQL engine in WebAssembly, so the committed SQL is
// executed rather than faked. The runner's lock, and the image applying the
// history before it serves, are proven against the pinned PostgreSQL image by
// bin/tests/db-migrate.e2e.sh.

const ORDERED = "tests/fixtures/ordered-migrations";
const BROKEN = "tests/fixtures/broken-migrations";

async function apply(client: PGlite, folder: string): Promise<void> {
  await migrate(drizzle({ client }), {
    ...MIGRATIONS,
    migrationsFolder: folder,
  });
}

async function count(client: PGlite, statement: string): Promise<number> {
  const { rows } = await client.query<{ count: number }>(statement);
  return rows[0]?.count ?? Number.NaN;
}

const recorded = (client: PGlite): Promise<number> =>
  count(
    client,
    "select count(*)::int as count from drizzle.__drizzle_migrations",
  );

const tables = (client: PGlite, name: string): Promise<number> =>
  count(
    client,
    `select count(*)::int as count from information_schema.tables where table_name = '${name}'`,
  );

test("[database-14fedb] applying to an empty database applies the history in folder order", async () => {
  const client = new PGlite();
  try {
    // The second fixture migration alters what the first creates, so applying
    // them out of order cannot succeed.
    await apply(client, ORDERED);
    expect(await recorded(client)).toBe(2);
    expect(
      await count(
        client,
        "select count(*)::int as count from information_schema.columns where table_name = 'ordered' and column_name = 'second'",
      ),
    ).toBe(1);
  } finally {
    await client.close();
  }
});

test("[database-f98489] applying a current database changes nothing", async () => {
  const client = new PGlite();
  try {
    await apply(client, ORDERED);
    await apply(client, ORDERED);
    expect(await recorded(client)).toBe(2);
  } finally {
    await client.close();
  }
});

test("[database-129a02] a failing migration rolls back its run and records nothing", async () => {
  const client = new PGlite();
  try {
    let message = "";
    try {
      await apply(client, BROKEN);
    } catch (error) {
      message = error instanceof Error ? error.message : String(error);
    }
    expect(message).toContain("nosuchtype");
    expect(await tables(client, "kept")).toBe(0);
    expect(await tables(client, "broken")).toBe(0);
    expect(await recorded(client)).toBe(0);
  } finally {
    await client.close();
  }
});

test("the service's own history applies", async () => {
  const client = new PGlite();
  try {
    await apply(client, `${serviceRoot}/${MIGRATIONS.migrationsFolder}`);
    const files = await Array.fromAsync(
      new Bun.Glob("*/migration.sql").scan({
        cwd: `${serviceRoot}/${MIGRATIONS.migrationsFolder}`,
      }),
    );
    expect(await recorded(client)).toBe(files.length);
  } finally {
    await client.close();
  }
});

test("[database-cd5777] the command prints its usage and needs no database", () => {
  const run = Bun.spawnSync(
    [process.execPath, "tooling/migrate.ts", "--help"],
    {
      cwd: serviceRoot,
      env: { PATH: process.env.PATH ?? "" },
      stdout: "pipe",
      stderr: "pipe",
    },
  );
  const output = run.stdout.toString();
  expect(run.exitCode).toBe(0);
  expect(output).toContain("usage: bun run db:migrate");
  expect(output).toContain("advisory lock");
  expect(output).toContain("no down migrations");
  expect(output).toContain("POSTGRES_URL");
});
