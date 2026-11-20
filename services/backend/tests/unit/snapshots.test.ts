import { expect, test } from "bun:test";
import {
  existsSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import {
  hasOneSnapshot,
  keepOneSnapshot,
  migrations,
  snapshotted,
} from "../../tooling/snapshots";

// A migrations folder: each named migration with its SQL and, when given, its
// snapshot.
function folderOf(
  entries: Record<string, { type: string; id: string } | null>,
): string {
  const folder = mkdtempSync(join(tmpdir(), "snapshots-"));
  for (const [name, snapshot] of Object.entries(entries)) {
    mkdirSync(join(folder, name));
    writeFileSync(join(folder, name, "migration.sql"), "SELECT 1;\n");
    if (snapshot)
      writeFileSync(
        join(folder, name, "snapshot.json"),
        JSON.stringify(snapshot),
      );
  }
  writeFileSync(join(folder, "stray.txt"), "not a migration\n");
  return folder;
}

test("[database-811aa6] migrations are the folders, oldest first, and only some keep a snapshot", () => {
  const folder = folderOf({
    "0002_second": { type: "diff", id: "b" },
    "0001_first": null,
  });
  try {
    expect(migrations(folder)).toEqual(["0001_first", "0002_second"]);
    expect(snapshotted(folder)).toEqual(["0002_second"]);
  } finally {
    rmSync(folder, { recursive: true });
  }
});

test("[database-811aa6] one base snapshot in the newest migration is the only valid layout", () => {
  const cases = [
    [{}, true],
    [{ "0001_first": null, "0002_second": { type: "base", id: "b" } }, true],
    [{ "0001_first": null, "0002_second": { type: "diff", id: "b" } }, false],
    [{ "0001_first": { type: "base", id: "a" }, "0002_second": null }, false],
    [
      {
        "0001_first": { type: "base", id: "a" },
        "0002_second": { type: "base", id: "b" },
      },
      false,
    ],
  ] as const;
  for (const [entries, valid] of cases) {
    const folder = folderOf(entries);
    try {
      expect(hasOneSnapshot(folder)).toBe(valid);
    } finally {
      rmSync(folder, { recursive: true });
    }
  }
});

test("[database-811aa6] keeping one snapshot writes the base under the newest id and deletes the rest", () => {
  const folder = folderOf({
    "0001_first": { type: "base", id: "a" },
    "0002_second": { type: "diff", id: "b" },
    "0003_third": { type: "diff", id: "c" },
  });
  try {
    expect(keepOneSnapshot(folder, { type: "base", id: "fresh" })).toEqual([
      "0001_first",
      "0002_second",
    ]);
    expect(snapshotted(folder)).toEqual(["0003_third"]);
    const kept = readFileSync(join(folder, "0003_third/snapshot.json"), "utf8");
    expect(JSON.parse(kept)).toEqual({ type: "base", id: "c" });
    expect(kept).toEndWith("}\n");
    expect(hasOneSnapshot(folder)).toBe(true);
    expect(existsSync(join(folder, "0001_first/migration.sql"))).toBe(true);
  } finally {
    rmSync(folder, { recursive: true });
  }
});

test("keeping one snapshot of no migrations deletes nothing", () => {
  const folder = folderOf({});
  try {
    expect(keepOneSnapshot(folder, { type: "base", id: "fresh" })).toEqual([]);
  } finally {
    rmSync(folder, { recursive: true });
  }
});
