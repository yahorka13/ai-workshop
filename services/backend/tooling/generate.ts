// `bun run db:generate [drizzle-kit generate flags]`: generates the migration,
// then keeps one snapshot (tooling/snapshots.ts). The base it keeps is
// generated from the schema module into a scratch folder, so it is the whole
// schema the new migration leaves behind.
import { mkdtempSync, readdirSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { z } from "zod";
import { hasOneSnapshot, keepOneSnapshot, readSnapshot } from "./snapshots";

// Read at run time, so the tooling typechecks without the project's config.
const { default: config } = z
  .object({
    default: z.looseObject({
      dialect: z.string(),
      schema: z.string(),
      out: z.string(),
    }),
  })
  .parse(await import(resolve("drizzle.config.ts")));
const { out } = config;

function kit(args: string[], output: "inherit" | "pipe"): void {
  const run = Bun.spawnSync(
    [process.execPath, "--bun", "drizzle-kit", "generate", ...args],
    { stdin: "inherit", stdout: output, stderr: "inherit" },
  );
  // A run a signal ended has no exit code at run time, whatever the type says.
  if (run.exitCode !== 0) process.exit(run.exitCode > 0 ? run.exitCode : 1);
}

kit(process.argv.slice(2), "inherit");
if (!hasOneSnapshot(out)) {
  const scratch = mkdtempSync(join(tmpdir(), "base-snapshot-"));
  try {
    kit(
      [
        "--dialect",
        config.dialect,
        "--schema",
        config.schema,
        "--out",
        scratch,
        "--name",
        "base",
      ],
      "pipe",
    );
    const [base] = readdirSync(scratch);
    const snapshot = readSnapshot(join(scratch, `${base}/snapshot.json`));
    const deleted = keepOneSnapshot(out, snapshot);
    console.log(
      `Kept one snapshot, the whole schema, in the newest migration; deleted ${deleted.length} older.`,
    );
  } finally {
    rmSync(scratch, { recursive: true, force: true });
  }
}
