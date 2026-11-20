import { expect, test } from "bun:test";
import { readFileSync, readdirSync } from "node:fs";
import { join } from "node:path";
import { fixture } from "../fixtures";
import { at } from "../support/defined";

test("[database-36f3ec] generating writes a migration folder with its SQL and a base snapshot", () => {
  const project = fixture({
    "drizzle.config.ts": `import { defineConfig } from "drizzle-kit";
export default defineConfig({
  dialect: "postgresql",
  schema: "./src/db/schema/index.ts",
  out: "./src/db/migrations",
});
`,
    "src/db/schema/index.ts": `import { pgTable, text, uuid } from "drizzle-orm/pg-core";
export const probes = pgTable("probes", {
  id: uuid("id").primaryKey(),
  label: text("label").notNull(),
});
`,
  });
  try {
    const generated = project.run("tooling/generate.ts");
    expect(generated.exitCode).toBe(0);
    const folder = join(project.root, "src/db/migrations");
    const migrations = readdirSync(folder);
    expect(migrations.length).toBe(1);
    const migration = join(folder, at(migrations, 0, "migrations"));
    expect(readdirSync(migration).sort()).toEqual([
      "migration.sql",
      "snapshot.json",
    ]);
    expect(
      JSON.parse(readFileSync(join(migration, "snapshot.json"), "utf8")),
    ).toMatchObject({ type: "base" });
    const sql = readFileSync(join(migration, "migration.sql"), "utf8");
    expect(sql).toContain('CREATE TABLE "probes"');
    expect(sql).toContain('"label" text NOT NULL');
  } finally {
    project.close();
  }
}, 60000);
