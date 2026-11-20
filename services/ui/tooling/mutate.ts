// bin/mutate's entry inside the mutate container:
//
//     bun tooling/mutate.ts                          # the whole source
//     bun tooling/mutate.ts --changed <file:a-b>...  # only these line ranges
//
// Runs Stryker, writes reports/summary.md and exits 1 when a changed run
// leaves a mutant survived or uncovered. MUTATE_FULL_GLOB, comma separated,
// narrows a whole-source run (bin/tests/mutate.e2e.sh uses it).
import { mkdirSync, rmSync, writeFileSync } from "node:fs";
import { inScope, readReport, summarize, type Mode } from "./mutation-report";

const [flag, ...ranges] = process.argv.slice(2);
const mode: Mode = flag === "--changed" ? "changed" : "full";
if (
  (flag !== undefined && mode === "full") ||
  (mode === "changed" && ranges.length === 0)
) {
  console.error("usage: bun tooling/mutate.ts [--changed <file:start-end>...]");
  process.exit(2);
}

const mutate =
  mode === "changed"
    ? ranges.filter((range) => inScope(range.split(":")[0] ?? ""))
    : (process.env.MUTATE_FULL_GLOB ?? "").split(",").filter((g) => g !== "");
if (mode === "changed" && mutate.length === 0) {
  console.log("Nothing to mutate.");
  process.exit(0);
}

rmSync("reports", { recursive: true, force: true });
const run = Bun.spawnSync(
  [
    "bun",
    "run",
    "mutate:stryker",
    ...(mutate.length > 0 ? ["--mutate", mutate.join(",")] : []),
  ],
  { stdout: "inherit", stderr: "inherit" },
);
// A run a signal ended has no exit code at run time, whatever the type says.
if (run.exitCode !== 0) process.exit(run.exitCode > 0 ? run.exitCode : 1);

const { markdown, failing } = summarize(
  readReport("reports/mutation.json"),
  mode,
);
mkdirSync("reports", { recursive: true });
writeFileSync("reports/summary.md", markdown);
console.log(`\n${markdown}`);
if (failing > 0) {
  console.error(
    `${String(failing)} mutant(s) survived or are not covered by any test.`,
  );
  process.exit(1);
}
