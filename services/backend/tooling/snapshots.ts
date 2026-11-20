// drizzle-kit 1.0 rebuilds the schema from one base snapshot, the whole
// schema, and replays the diff snapshots after it; the migrator reads only each
// migration.sql. So only the newest migration keeps a snapshot, and it is a
// base: tooling/generate.ts folds each newly generated diff into one.
import {
  existsSync,
  readFileSync,
  readdirSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import { join } from "node:path";
import { z } from "zod";

// drizzle-kit's snapshot: what this tooling reads of it, the rest kept as is.
const snapshotSchema = z.looseObject({ type: z.string(), id: z.string() });
export type Snapshot = z.infer<typeof snapshotSchema>;

/** A snapshot file's contents, failing on anything that is not one. */
export function readSnapshot(path: string): Snapshot {
  return snapshotSchema.parse(JSON.parse(readFileSync(path, "utf8")));
}

const snapshotPath = (folder: string, migration: string): string =>
  join(folder, migration, "snapshot.json");

/** The migration folders, oldest first. */
export function migrations(folder: string): string[] {
  return readdirSync(folder, { withFileTypes: true })
    .filter((entry) => entry.isDirectory())
    .map((entry) => entry.name)
    .sort();
}

/** The migrations that keep a snapshot, oldest first. */
export function snapshotted(folder: string): string[] {
  return migrations(folder).filter((name) =>
    existsSync(snapshotPath(folder, name)),
  );
}

/** Whether only the newest migration keeps a snapshot, and it is a base. */
export function hasOneSnapshot(folder: string): boolean {
  const newest = migrations(folder).at(-1);
  if (newest === undefined) return true;
  const kept = snapshotted(folder);
  if (kept.length !== 1 || kept[0] !== newest) return false;
  return readSnapshot(snapshotPath(folder, newest)).type === "base";
}

/**
 * Writes `base`, the whole schema, as the newest migration's snapshot under
 * that snapshot's id, so a diff generated on top of it still finds its parent,
 * and deletes every older snapshot. Returns the migrations it deleted one from.
 */
export function keepOneSnapshot(folder: string, base: Snapshot): string[] {
  const newest = migrations(folder).at(-1);
  if (newest === undefined) return [];
  const path = snapshotPath(folder, newest);
  const { id } = readSnapshot(path);
  writeFileSync(path, `${JSON.stringify({ ...base, id }, null, 2)}\n`);
  const older = snapshotted(folder).filter((name) => name !== newest);
  for (const name of older) rmSync(snapshotPath(folder, name));
  return older;
}
