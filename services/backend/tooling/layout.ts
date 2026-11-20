// What a well-formed migrations folder holds: one `<timestamp>_<name>/` folder
// per migration with its migration.sql, nothing loose beside them, and one
// base snapshot in the newest migration only.
import { existsSync, readdirSync } from "node:fs";
import { join } from "node:path";
import { hasOneSnapshot, migrations } from "./snapshots";

// drizzle-kit's folder name: a 14-digit UTC timestamp and a snake_case name.
const FOLDER_NAME = /^\d{14}_[a-z0-9_]+$/;

/** Every problem with the migrations folder's layout, empty when it is well formed. */
export function layoutProblems(folder: string): string[] {
  const problems: string[] = [];
  const loose = readdirSync(folder, { withFileTypes: true })
    .filter((entry) => !entry.isDirectory() && entry.name !== ".gitkeep")
    .map((entry) => entry.name);
  if (loose.length > 0)
    problems.push(
      `the migrations folder holds only migration folders; move or delete ${loose.join(", ")}`,
    );
  const names = migrations(folder);
  const misnamed = names.filter((name) => !FOLDER_NAME.test(name));
  if (misnamed.length > 0)
    problems.push(
      `name each migration folder <timestamp>_<name>: ${misnamed.join(", ")}`,
    );
  const incomplete = names.filter(
    (name) => !existsSync(join(folder, name, "migration.sql")),
  );
  if (incomplete.length > 0)
    problems.push(
      `each migration folder needs migration.sql: ${incomplete.join(", ")}`,
    );
  if (incomplete.length === 0 && !hasOneSnapshot(folder))
    problems.push(
      `keep only the latest snapshot, a base of the whole schema, in ${names.at(-1) ?? "the newest migration"}; run \`bun run db:generate\` to fold the others into it.`,
    );
  return problems;
}
