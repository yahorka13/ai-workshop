import { expect, test } from "bun:test";
import { fixture } from "../fixtures";
import { lintRules } from "../support/lint-report";

// Source that passes every other rule and sits <over> one step past (true) or
// at (false) the limit of each complexity and size rule.
const lines = (count: number, line: (index: number) => string): string =>
  Array.from({ length: count }, (_, index) => line(index)).join("\n");

const branchy = (name: string, branches: number): string =>
  `export function ${name}(value: number): number {\n  let total = 0;\n${lines(
    branches,
    (index) => `  if (value === ${String(index)}) {\n    total += 1;\n  }`,
  )}\n  return total;\n}\n`;

const nested = (depth: number): string =>
  `export function probe(value: number): number {\n${lines(
    depth,
    (index) => `${"  ".repeat(index + 1)}if (value > ${String(index)}) {`,
  )}\n${"  ".repeat(depth + 1)}return 1;\n${lines(
    depth,
    (index) => `${"  ".repeat(depth - index)}}`,
  )}\n  return 0;\n}\n`;

const params = (count: number): string => {
  const names = Array.from(
    { length: count },
    (_, index) => `p${String(index)}`,
  );
  return `export function probe(${names.map((name) => `${name}: number`).join(", ")}): number {\n  return ${names.join(" + ")};\n}\n`;
};

// A function of <count> lines, from its signature to its closing brace.
const long = (count: number): string =>
  `export function probe(value: number): number {\n  let total = value;\n${lines(
    count - 4,
    () => "  total += 1;",
  )}\n  return total;\n}\n`;

const file = (count: number): string =>
  `${lines(count, (index) => `export const v${String(index)} = ${String(index)};`)}\n`;

const limits = [
  ["complexity", (over: boolean) => branchy("probe", over ? 10 : 9)],
  ["max-depth", (over: boolean) => nested(over ? 4 : 3)],
  ["max-params", (over: boolean) => params(over ? 4 : 3)],
  ["max-lines-per-function", (over: boolean) => long(over ? 51 : 50)],
  ["max-lines", (over: boolean) => file(over ? 301 : 300)],
] as const;

// One type-aware run lints every limit over and at, once for all the tests
// below: a run per case is too slow on CI. The first test to ask pays for it,
// so each gets 90 s, at least three times that run on CI: a slower runner
// passes and a hang still fails.
let report: Map<string, string[]> | undefined;
const findings = (): Map<string, string[]> => {
  if (report !== undefined) return report;
  const project = fixture(
    Object.fromEntries(
      limits.flatMap(([rule, source]) => [
        [`src/${rule}-over.ts`, source(true)],
        [`src/${rule}-at.ts`, source(false)],
      ]),
    ),
  );
  try {
    report = lintRules(project, "src").rules;
    return report;
  } finally {
    project.close();
  }
};

for (const [rule] of limits) {
  test(`[service-checks-ec3fd1] code over the ${rule} limit fails lint`, () => {
    expect(findings().get(`${rule}-over.ts`)).toContain(rule);
    expect(findings().get(`${rule}-at.ts`)).toEqual([]);
  }, 90000);
}
