// @ts-check
// Mutation testing for bin/mutate (design.md of change 10-a51b97). Run it
// through bin/mutate, which builds the Dockerfile's mutate target, passes the
// changed lines and reads the reports from reports/.
import { readdirSync } from "node:fs";
import { env } from "node:process";

// Tests of tooling, lint and gates, not of src/: they gain nothing from
// mutants, and the gates fail inside Stryker's sandbox.
const TOOLING = new Set([
  "unit/contracts.test.ts",
  "unit/coverage-report.test.ts",
  "unit/mutation-report.test.ts",
  "unit/stories.test.ts",
  "unit/story-ids.test.ts",
  "unit/stryker-config.test.ts",
  "unit/stryker-ignore-class-names.test.ts",
  "unit/stryker-ignore-error-messages.test.ts",
  "unit/test-policy.test.ts",
  "integration/contracts.test.ts",
  "integration/i18n-keys.test.ts",
  "integration/lint-limits.test.ts",
  "integration/lint-rules.test.ts",
  "integration/structure-gates.test.ts",
]);
const testFiles = ["unit", "integration"].flatMap((suite) =>
  readdirSync(`tests/${suite}`, { recursive: true, encoding: "utf8" })
    .filter(
      (name) => /\.test\.tsx?$/.test(name) && !TOOLING.has(`${suite}/${name}`),
    )
    .sort()
    .map((name) => `tests/${suite}/${name}`),
);

const jobs = Number(env.FACTORY_JOBS ?? "");

export default {
  // The runner and the ignorers; no other plugin is loaded. The package
  // script mutate:stryker selects the runner with --testRunner bun: the Bun
  // runner's package is not named after it, so the file does not name it.
  plugins: [
    "@hughescr/stryker-bun-runner",
    "./tooling/stryker-ignore-error-messages.mjs",
    "./tooling/stryker-ignore-class-names.mjs",
  ],
  coverageAnalysis: "perTest",
  // The runner imports every mutated module before the tests run, so the entry
  // module, which renders the app when imported, is left out; its test
  // (tests/integration/main.test.tsx) proves it.
  mutate: [
    "src/**/*.{ts,tsx}",
    "!src/main.tsx",
    "!src/**/*.stories.tsx",
    "!src/services/graphql/generated/**",
    "!src/i18n/i18next.d.ts",
  ],
  ignorers: ["error-messages", "class-names"],
  dryRunTimeoutMinutes: 15, // hosted runners can take over Stryker's default 5 for the first test run
  bun: {
    testFiles,
    timeout: 600_000, // the dry run runs both suites once; the 10 s default cannot
    bunArgs: ["--timeout", "30000"], // the integration suite's per-test limit
  },
  ...(Number.isInteger(jobs) && jobs > 0 ? { concurrency: jobs } : {}),
  reporters: ["clear-text", "progress", "json", "html"],
  jsonReporter: { fileName: "reports/mutation.json" },
  htmlReporter: { fileName: "reports/mutation.html" },
  thresholds: { high: 100, low: 100, break: null },
  tempDirName: ".stryker-tmp",
  cleanTempDir: "always",
};
