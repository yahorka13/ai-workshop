import { expect, test } from "bun:test";
import {
  existsSync,
  mkdirSync,
  readFileSync,
  readdirSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import { join } from "node:path";
import { readSnapshot } from "../../tooling/snapshots";
import { fixture, type Fixture } from "../fixtures";
import { defined } from "../support/defined";

const drizzleConfig = `import { defineConfig } from "drizzle-kit";

export default defineConfig({
  dialect: "postgresql",
  schema: "./src/db/schema/index.ts",
  out: "./src/db/migrations",
});
`;

const probes = `import { pgTable, text, uuid } from "drizzle-orm/pg-core";

export const probes = pgTable("probes", {
  id: uuid("id").primaryKey(),
  label: text("label").notNull(),
});
`;

// A fixture whose committed migrations match its schema module.
function generated(): Fixture {
  const project = fixture({
    "drizzle.config.ts": drizzleConfig,
    "src/db/schema/index.ts": probes,
  });
  const run = project.run(
    "--bun",
    "drizzle-kit",
    "generate",
    "--name",
    "initial",
  );
  expect(run.exitCode).toBe(0);
  return project;
}

function contents(folder: string): string[] {
  return readdirSync(folder, { recursive: true, withFileTypes: true })
    .filter((entry) => entry.isFile())
    .map((entry) => {
      const path = join(entry.parentPath, entry.name);
      return `${path.slice(folder.length)}:${readFileSync(path, "utf8")}`;
    })
    .sort();
}

test("[database-753cbf] committed migrations that match the schema pass", () => {
  const project = generated();
  try {
    const verify = project.run("tooling/verify-migrations.ts");
    expect(verify.stdout.toString() + verify.stderr.toString()).toContain(
      "match the schema module",
    );
    expect(verify.exitCode).toBe(0);
  } finally {
    project.close();
  }
}, 60000);

test("[database-5b3ec0] a schema change with no migration fails and changes nothing", () => {
  const project = generated();
  const folder = join(project.root, "src/db/migrations");
  const before = contents(folder);
  try {
    const widened = `${probes}
export const widgets = pgTable("widgets", {
  id: uuid("id").primaryKey(),
  name: text("name").notNull(),
});
`;
    writeFileSync(join(project.root, "src/db/schema/index.ts"), widened);
    const verify = project.run("tooling/verify-migrations.ts");
    const output = verify.stdout.toString() + verify.stderr.toString();
    expect(verify.exitCode).not.toBe(0);
    expect(output).toContain("no committed migration");
    expect(output).toContain("widgets");
    expect(contents(folder)).toEqual(before);
  } finally {
    project.close();
  }
}, 60000);

test("[database-513dca] a migrations folder with a loose or incomplete migration fails", () => {
  const project = generated();
  const folder = join(project.root, "src/db/migrations");
  try {
    writeFileSync(join(folder, "0001_orphan.sql"), "SELECT 1;\n");
    const loose = project.run("tooling/verify-migrations.ts");
    const output = loose.stdout.toString() + loose.stderr.toString();
    expect(loose.exitCode).not.toBe(0);
    expect(output).toContain("only migration folders");
    expect(output).toContain("0001_orphan.sql");
    rmSync(join(folder, "0001_orphan.sql"));
    mkdirSync(join(folder, "0002_empty"));
    const incomplete = project.run("tooling/verify-migrations.ts");
    expect(incomplete.exitCode).not.toBe(0);
    expect(
      incomplete.stdout.toString() + incomplete.stderr.toString(),
    ).toContain("needs migration.sql: 0002_empty");
  } finally {
    project.close();
  }
}, 60000);

// A second migration, on top of the first one's snapshot.
const noted = `import { pgTable, text, uuid } from "drizzle-orm/pg-core";

export const probes = pgTable("probes", {
  id: uuid("id").primaryKey(),
  label: text("label").notNull(),
  note: text("note"),
});
`;

// Oldest first: readdirSync keeps the file system's order, unsorted on Linux.
function snapshotsOf(folder: string): (readonly [string, string])[] {
  return readdirSync(folder)
    .sort()
    .filter((name) => existsSync(join(folder, name, "snapshot.json")))
    .map(
      (name) =>
        [name, readSnapshot(join(folder, name, "snapshot.json")).type] as const,
    );
}

test("[database-811aa6] generating through db:generate keeps one base snapshot", () => {
  const project = generated();
  const folder = join(project.root, "src/db/migrations");
  try {
    writeFileSync(join(project.root, "src/db/schema/index.ts"), noted);
    const run = project.run("tooling/generate.ts", "--name", "note");
    expect(run.exitCode).toBe(0);
    expect(run.stdout.toString()).toContain("deleted 1 older");
    const newest = readdirSync(folder).sort().at(-1);
    expect(newest).toEndWith("_note");
    expect(snapshotsOf(folder)).toEqual([[defined(newest, "newest"), "base"]]);
    expect(project.run("tooling/verify-migrations.ts").exitCode).toBe(0);
    // Nothing to generate leaves the one snapshot as it is.
    const before = contents(folder);
    expect(project.run("tooling/generate.ts").exitCode).toBe(0);
    expect(contents(folder)).toEqual(before);
  } finally {
    project.close();
  }
}, 60000);

test("[database-811aa6] a snapshot left beside the newest fails verify until db:generate folds it", () => {
  const project = generated();
  const folder = join(project.root, "src/db/migrations");
  try {
    writeFileSync(join(project.root, "src/db/schema/index.ts"), noted);
    expect(
      project.run("--bun", "drizzle-kit", "generate", "--name", "note")
        .exitCode,
    ).toBe(0);
    expect(snapshotsOf(folder).map(([, type]) => type)).toEqual([
      "base",
      "diff",
    ]);
    const verify = project.run("tooling/verify-migrations.ts");
    const output = verify.stdout.toString() + verify.stderr.toString();
    expect(verify.exitCode).toBe(1);
    expect(output).toContain("keep only the latest snapshot");
    expect(output).toContain("bun run db:generate");
    expect(project.run("tooling/generate.ts").exitCode).toBe(0);
    expect(snapshotsOf(folder).map(([, type]) => type)).toEqual(["base"]);
    expect(project.run("tooling/verify-migrations.ts").exitCode).toBe(0);
  } finally {
    project.close();
  }
}, 60000);

test("the committed migrations of this service pass the check", () => {
  const verify = Bun.spawnSync(
    [process.execPath, "tooling/verify-migrations.ts"],
    {
      cwd: new URL("../..", import.meta.url).pathname,
      stdout: "pipe",
      stderr: "pipe",
    },
  );
  expect(verify.stdout.toString() + verify.stderr.toString()).toContain(
    "match the schema module",
  );
  expect(verify.exitCode).toBe(0);
}, 60000);
