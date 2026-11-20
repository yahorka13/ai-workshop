import { existsSync, readFileSync, rmSync } from "node:fs";
import { availableParallelism } from "node:os";
import {
  coverageSources,
  holdsCode,
  missingSuites,
  testWorkers,
  validateCoverage,
} from "./coverage-report";

const empty = missingSuites([
  ...new Bun.Glob("tests/{unit,integration}/**/*").scanSync({
    onlyFiles: true,
  }),
]);
if (empty.length > 0) {
  console.error(`No test files in: ${empty.join(", ")}`);
  process.exit(1);
}
rmSync("coverage", { recursive: true, force: true });
const run = Bun.spawnSync(
  [
    process.execPath,
    "test",
    "./tests/unit",
    "./tests/integration",
    "--coverage",
    "--coverage-reporter=text",
    "--coverage-reporter=lcov",
    "--timeout",
    "30000",
    `--parallel=${testWorkers(process.env.FACTORY_JOBS, availableParallelism())}`,
    // Each worker keeps one module registry across its files, as the single
    // serial process did, so a file's costly setup is built once per worker.
    "--no-isolate",
  ],
  { stdout: "inherit", stderr: "inherit" },
);
// A run a signal ended has no exit code at run time, whatever the type says.
if (run.exitCode !== 0) process.exit(run.exitCode > 0 ? run.exitCode : 1);
const sources = coverageSources([
  ...new Bun.Glob("src/**/*.{ts,tsx}").scanSync({ onlyFiles: true }),
]).filter((path) => holdsCode(readFileSync(path, "utf8")));
if (sources.length === 0) {
  console.error("No production source files found under src/");
  process.exit(1);
}
const path = "coverage/lcov.info";
const errors = validateCoverage(
  existsSync(path) ? readFileSync(path, "utf8") : "",
  sources,
);
if (errors.length > 0) {
  console.error(errors.join("\n"));
  process.exit(1);
}
