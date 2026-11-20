// Fail when the committed migrations no longer describe the schema module, or
// when the migrations folder is malformed. Read-only: drift is checked by
// generating into a scratch copy, never into the committed folder.
import {
  cpSync,
  mkdtempSync,
  readFileSync,
  readdirSync,
  rmSync,
  symlinkSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { layoutProblems } from "./layout";
import { migrations as migrationsOf } from "./snapshots";

const folder = "src/db/migrations";

function fail(message: string): never {
  console.error(message);
  process.exit(1);
}

// One folder per migration, holding the SQL the migrator runs; nothing else.
const problems = layoutProblems(folder);
if (problems.length > 0) fail(problems.join("\n"));
const migrations = migrationsOf(folder);

const check = Bun.spawnSync(
  [process.execPath, "--bun", "drizzle-kit", "check"],
  {
    stdout: "pipe",
    stderr: "pipe",
  },
);
if (check.exitCode !== 0) {
  fail(
    `drizzle-kit check failed:\n${check.stdout.toString()}${check.stderr.toString()}`,
  );
}

// drizzle-kit only works inside a project: an out-of-tree `out` crashes its
// snapshot validation. So the drift check builds a scratch project that shares
// this one's dependencies and generates there, leaving the committed folder
// untouched.
const scratch = mkdtempSync(join(tmpdir(), "migration-drift-"));
try {
  cpSync("src/db", join(scratch, "src/db"), { recursive: true });
  for (const manifest of ["package.json", "tsconfig.json", "bunfig.toml"]) {
    cpSync(manifest, join(scratch, manifest));
  }
  symlinkSync(resolve("node_modules"), join(scratch, "node_modules"), "dir");
  cpSync("drizzle.config.ts", join(scratch, "drizzle.config.ts"));
  const out = join(scratch, folder);
  const before = readdirSync(out);
  const generate = Bun.spawnSync(
    [process.execPath, "--bun", "drizzle-kit", "generate"],
    { cwd: scratch, stdout: "pipe", stderr: "pipe" },
  );
  const output = generate.stdout.toString() + generate.stderr.toString();
  if (generate.exitCode !== 0) {
    fail(`could not generate into a scratch copy:\n${output}`);
  }
  const added = readdirSync(out)
    .filter((name) => !before.includes(name))
    .sort();
  if (added.length > 0) {
    const sql = added
      .map((name) => readFileSync(join(out, name, "migration.sql"), "utf8"))
      .join("\n");
    fail(
      `the schema has changes with no committed migration:\n\n${sql}\nRun \`bun run db:generate\` and commit the result.`,
    );
  }
} finally {
  rmSync(scratch, { recursive: true, force: true });
}

console.log(
  `${migrations.length} committed migration(s) match the schema module.`,
);
