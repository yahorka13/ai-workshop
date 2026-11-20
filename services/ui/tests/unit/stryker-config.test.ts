import { afterEach, expect, test } from "bun:test";
import { z } from "zod";

// What the tests read of the Stryker config.
const configSchema = z.object({
  default: z.looseObject({
    coverageAnalysis: z.string(),
    dryRunTimeoutMinutes: z.number(),
    mutate: z.array(z.string()),
    plugins: z.array(z.string()),
    ignorers: z.array(z.string()),
    jsonReporter: z.object({ fileName: z.string() }),
    htmlReporter: z.object({ fileName: z.string() }),
    thresholds: z.looseObject({ break: z.null() }),
    bun: z.looseObject({ testFiles: z.array(z.string()) }),
    concurrency: z.number().optional(),
  }),
});
type Config = z.infer<typeof configSchema>["default"];

// The config reads FACTORY_JOBS when it is imported, so each import that
// needs another value takes a fresh copy through a query string.
const load = async (
  jobs: string | undefined,
  copy: string,
): Promise<Config> => {
  if (jobs === undefined) delete process.env.FACTORY_JOBS;
  else process.env.FACTORY_JOBS = jobs;
  const module: unknown = await import(`../../stryker.config.mjs?${copy}`);
  return configSchema.parse(module).default;
};

const saved = process.env.FACTORY_JOBS;
afterEach(() => {
  if (saved === undefined) delete process.env.FACTORY_JOBS;
  else process.env.FACTORY_JOBS = saved;
});

test("[service-checks-c6a129] the first test run may take 15 minutes", async () => {
  const config = await load(undefined, "first");
  expect(config.dryRunTimeoutMinutes).toBe(15);
  expect(config.coverageAnalysis).toBe("perTest");
  expect(config.thresholds.break).toBeNull();
});

test("only application source is mutated: no entry module, stories, generated code or declarations", async () => {
  const config = await load(undefined, "scope");
  expect(config.mutate).toEqual([
    "src/**/*.{ts,tsx}",
    "!src/main.tsx",
    "!src/**/*.stories.tsx",
    "!src/services/graphql/generated/**",
    "!src/i18n/i18next.d.ts",
  ]);
  expect(config.ignorers).toEqual(["error-messages", "class-names"]);
  expect(config.plugins).toEqual([
    "@hughescr/stryker-bun-runner",
    "./tooling/stryker-ignore-error-messages.mjs",
    "./tooling/stryker-ignore-class-names.mjs",
  ]);
});

test("the mutate:stryker script runs Stryker with the Bun runner", async () => {
  const manifest = z
    .object({ scripts: z.record(z.string(), z.string()) })
    .parse(
      await Bun.file(new URL("../../package.json", import.meta.url)).json(),
    );
  expect(manifest.scripts["mutate:stryker"]).toBe(
    "stryker run --testRunner bun",
  );
  expect(manifest.scripts.mutate).toBe("bun tooling/mutate.ts");
});

test("the reports land in reports/", async () => {
  const config = await load(undefined, "reports");
  expect(config.jsonReporter).toEqual({ fileName: "reports/mutation.json" });
  expect(config.htmlReporter).toEqual({ fileName: "reports/mutation.html" });
});

test("both suites run, without the tests of tooling and gates", async () => {
  const { bun } = await load(undefined, "tests");
  expect(bun.testFiles).toContain("tests/unit/lib/next-path.test.ts");
  expect(bun.testFiles).toContain("tests/unit/components/Notice.test.tsx");
  expect(bun.testFiles).toContain("tests/integration/routes.test.tsx");
  expect(bun.testFiles).not.toContain("tests/unit/contracts.test.ts");
  expect(bun.testFiles).not.toContain("tests/integration/lint-rules.test.ts");
  expect(bun.testFiles).not.toContain("tests/unit/stryker-config.test.ts");
});

test("FACTORY_JOBS caps the workers only when it is a positive integer", async () => {
  expect((await load("3", "three")).concurrency).toBe(3);
  expect((await load(undefined, "unset")).concurrency).toBeUndefined();
  expect((await load("0", "zero")).concurrency).toBeUndefined();
  expect((await load("two", "word")).concurrency).toBeUndefined();
});
