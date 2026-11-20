import { expect, test } from "bun:test";
import { resolve } from "node:path";
import {
  coverageSources,
  holdsCode,
  missingSuites,
  testWorkers,
  validateCoverage,
} from "../../tooling/coverage-report";

const full =
  "TN:\nSF:src/app.ts\nFNF:1\nFNH:1\nDA:1,1\nLF:1\nLH:1\nend_of_record\n";

test("[service-checks-0a7378] accepts full line/function coverage and absolute paths", () => {
  expect(validateCoverage(full, ["src/app.ts"])).toEqual([]);
  expect(
    validateCoverage(full.replace("src/app.ts", resolve("src/app.ts")), [
      "src/app.ts",
    ]),
  ).toEqual([]);
  expect(
    validateCoverage(full.replace("FNF:1\nFNH:1", "FNF:0\nFNH:0"), [
      "src/app.ts",
    ]),
  ).toEqual([]);
});

test("[service-checks-3c1469] rejects uncovered lines and functions", () => {
  expect(
    validateCoverage(full.replace("DA:1,1", "DA:1,0").replace("LH:1", "LH:0"), [
      "src/app.ts",
    ]).join("\n"),
  ).toContain("src/app.ts");
  expect(
    validateCoverage(full.replace("FNH:1", "FNH:0"), ["src/app.ts"]).join("\n"),
  ).toContain("function");
});

for (const report of [
  "",
  "garbage",
  full.replace("end_of_record\n", ""),
  full.replace("LH:1\n", ""),
  full.replace("FNF:1", "FNF:NaN"),
  full.replace("FNH:1", "FNH:2"),
  full.replace("DA:1,1", "DA:1,-1"),
  full.replace("LF:1", "LF:2"),
  full + full,
]) {
  test(`[service-checks-cdc6fa] rejects invalid report ${JSON.stringify(report)}`, () => {
    expect(validateCoverage(report, ["src/app.ts"]).length).toBeGreaterThan(0);
  });
}

test("[service-checks-cdc6fa] identifies modules absent from a report", () => {
  expect(
    validateCoverage(full, ["src/app.ts", "src/extra.ts"]).join("\n"),
  ).toContain("src/extra.ts");
});

test("[service-checks-0a7378] declaration files are not coverage sources", () => {
  expect(coverageSources(["src/b.tsx", "src/env.d.ts", "src/a.ts"])).toEqual([
    "src/a.ts",
    "src/b.tsx",
  ]);
  expect(
    validateCoverage(full, coverageSources(["src/app.ts", "src/env.d.ts"])),
  ).toEqual([]);
});

test("generated typed documents are not coverage sources, other src/ files are", () => {
  expect(
    coverageSources([
      "src/services/graphql/generated/graphql.ts",
      "src/services/graphql/client.ts",
      "src/generated.ts",
      "src/hooks/generated/probe.ts",
    ]),
  ).toEqual([
    "src/generated.ts",
    "src/hooks/generated/probe.ts",
    "src/services/graphql/client.ts",
  ]);
});

test("stories never count toward coverage, and components still do", () => {
  expect(
    coverageSources([
      "src/components/ui/button.stories.tsx",
      "src/components/ui/button.tsx",
      "src\\components\\Header.stories.tsx",
    ]),
  ).toEqual(["src/components/ui/button.tsx"]);
});

test("[service-checks-cdc6fa] a suite with no test file is reported", () => {
  expect(
    missingSuites(["tests/unit/a.test.ts", "tests/integration/b.test.ts"]),
  ).toEqual([]);
  expect(missingSuites(["tests/integration/b.test.ts"])).toEqual([
    "tests/unit",
  ]);
  expect(
    missingSuites(["tests/unit/a.test.ts", "tests/unit/helper.ts"]),
  ).toEqual(["tests/integration"]);
  expect(missingSuites([])).toEqual(["tests/unit", "tests/integration"]);
});

test("[service-checks-db3dcd] coverage runs FACTORY_JOBS workers, else every available core", () => {
  expect(testWorkers("4", 10)).toBe(4);
  expect(testWorkers(undefined, 10)).toBe(10);
  expect(testWorkers("", 3)).toBe(3);
  for (const bad of ["0", "-1", "abc", "2.5", "01"])
    expect(() => testWorkers(bad, 10)).toThrow(
      `FACTORY_JOBS must be a positive integer, not ${bad}`,
    );
});

test("[service-checks-db3dcd] a report with a source twice, as from unmerged workers, fails", () => {
  expect(validateCoverage(full + full, ["src/app.ts"])).toContain(
    "Invalid or duplicate coverage source: src/app.ts",
  );
});

test("[service-checks-cdc6fa] a module that compiles to no code is not a coverage source", () => {
  expect(holdsCode("// the schema\nexport {};\n")).toBe(false);
  expect(holdsCode("export type Port = number;\n")).toBe(false);
  expect(holdsCode('import type { A } from "./a";\nexport type B = A;\n')).toBe(
    false,
  );
  expect(holdsCode("export const port = 4000;\n")).toBe(true);
  expect(holdsCode('export * from "./tables";\n')).toBe(true);
});
