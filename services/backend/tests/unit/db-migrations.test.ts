import { afterEach, expect, test } from "bun:test";
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { layoutProblems } from "../../tooling/layout";

let folder = "";

afterEach(() => {
  rmSync(folder, { recursive: true, force: true });
});

// A scratch migrations folder holding the given files.
function migrations(files: Record<string, string>): string {
  folder = mkdtempSync(join(tmpdir(), "migrations-"));
  for (const [name, content] of Object.entries(files)) {
    mkdirSync(join(folder, name, ".."), { recursive: true });
    writeFileSync(join(folder, name), content);
  }
  return folder;
}

const base = JSON.stringify({ type: "base", id: "a" });
const diff = JSON.stringify({ type: "diff", id: "b" });

test("an empty history, or one base snapshot in the newest migration, is well formed", () => {
  expect(layoutProblems(migrations({ ".gitkeep": "" }))).toEqual([]);
  expect(
    layoutProblems(
      migrations({
        "20261016121900_first/migration.sql": "select 1;",
        "20261016122000_second/migration.sql": "select 2;",
        "20261016122000_second/snapshot.json": base,
      }),
    ),
  ).toEqual([]);
});

test("[database-513dca] a loose file is named", () => {
  const problems = layoutProblems(migrations({ "0001_orphan.sql": "" }));
  expect(problems).toHaveLength(1);
  expect(problems[0]).toContain("only migration folders");
  expect(problems[0]).toContain("0001_orphan.sql");
});

test("[database-513dca] a folder not named <timestamp>_<name> is named", () => {
  const problems = layoutProblems(
    migrations({
      "initial/migration.sql": "select 1;",
      "initial/snapshot.json": base,
    }),
  );
  expect(problems).toEqual([
    "name each migration folder <timestamp>_<name>: initial",
  ]);
});

test("[database-513dca] a folder without migration.sql is named", () => {
  const problems = layoutProblems(
    migrations({ "20261016121900_first/snapshot.json": base }),
  );
  expect(problems).toEqual([
    "each migration folder needs migration.sql: 20261016121900_first",
  ]);
});

test("[database-513dca] a second snapshot, or a diff one, fails", () => {
  for (const files of [
    {
      "20261016121900_first/migration.sql": "select 1;",
      "20261016121900_first/snapshot.json": base,
      "20261016122000_second/migration.sql": "select 2;",
      "20261016122000_second/snapshot.json": base,
    },
    {
      "20261016121900_first/migration.sql": "select 1;",
      "20261016121900_first/snapshot.json": diff,
    },
  ]) {
    const problems = layoutProblems(migrations(files));
    expect(problems).toHaveLength(1);
    expect(problems[0]).toContain("keep only the latest snapshot");
    rmSync(folder, { recursive: true, force: true });
  }
});
