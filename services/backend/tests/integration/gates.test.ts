import { expect, test } from "bun:test";
import { readFileSync, readdirSync, mkdirSync, writeFileSync } from "node:fs";
import { basename } from "node:path";
import { fixture } from "../fixtures";
import { LintReport, lintRules } from "../support/lint-report";

// A test that runs type-aware ESLint or tsc in a fixture gets 90 s: at least
// three times its time on CI, so a slower runner passes and a hang still fails.

test("[service-checks-f37672] Bun test filenames all receive assertion policy", () => {
  // Distinct stems: one project cannot hold files that differ only by extension.
  const names = [
    "one.test.ts",
    "two.spec.ts",
    "three.test.tsx",
    "four.test.js",
    "five_test.ts",
    "six_spec.jsx",
  ];
  // One type-aware run for every name: a run per name is too slow on CI.
  const project = fixture(
    Object.fromEntries(
      names.map((name) => [
        `tests/unit/${name}`,
        'import { test } from "bun:test"; const title = "probe"; test(title, () => {});\n',
      ]),
    ),
  );
  try {
    const { exitCode, rules } = lintRules(
      project,
      ...names.map((name) => `tests/unit/${name}`),
    );
    expect(exitCode).not.toBe(0);
    for (const name of names) {
      expect(rules.get(name)).toContain("local/require-assertion");
    }
  } finally {
    project.close();
  }
}, 90000);

test("[service-checks-0a7378] [service-checks-3c1469] [service-checks-cdc6fa] actual coverage accepts full source and rejects gaps", () => {
  for (const [source, expression, valid] of [
    ["export const value = 1;\n", "value", true],
    [
      "export const value = 1;\nexport function unused() {\n  return 2;\n}\n",
      "value",
      false,
    ],
    [
      "export function value(flag: boolean) {\n  if (flag) {\n    return 1;\n  }\n  return 2;\n}\n",
      "value(true)",
      false,
    ],
  ] as const) {
    const project = fixture({
      "src/probe.ts": source,
      "tests/unit/probe.test.ts": `import { expect, test } from "bun:test"; import { value } from "../../src/probe"; test("value", () => expect(${expression}).toBe(1));\n`,
      "tests/integration/probe.test.ts":
        'import { expect, test } from "bun:test"; test("assembled", () => expect(true).toBe(true));\n',
    });
    try {
      expect(project.run("run", "coverage").exitCode === 0).toBe(valid);
      if (valid) {
        expect(
          readFileSync(`${project.root}/coverage/lcov.info`, "utf8"),
        ).toContain("src/probe.ts");
        writeFileSync(
          `${project.root}/src/extra.ts`,
          "export const extra = 2;\n",
        );
        const missing = project.run("run", "coverage");
        expect(missing.exitCode).not.toBe(0);
        expect(missing.stderr.toString()).toContain("src/extra.ts");
      }
    } finally {
      project.close();
    }
  }
}, 30000);

test("[service-checks-cdc6fa] failed current tests cannot reuse stale successful coverage", () => {
  const project = fixture({
    "src/probe.ts": "export const value = 1;\n",
    "tests/unit/probe.test.ts":
      'import { expect, test } from "bun:test"; test("fails", () => expect(1).toBe(2));\n',
  });
  try {
    mkdirSync(`${project.root}/coverage`);
    writeFileSync(`${project.root}/coverage/lcov.info`, "stale-success");
    const result = project.run("run", "coverage");
    expect(result.exitCode).not.toBe(0);
    expect(result.stderr.toString()).not.toContain("stale-success");
  } finally {
    project.close();
  }
}, 30000);

// One type-aware run lints every case: a run per case is too slow on CI.
test("[service-checks-f37672] [service-checks-1a0230] [service-checks-b489e4] real lint enforces assertions", () => {
  const cases = {
    "none.test.ts": ["", false],
    "has-assertions.test.ts": ["assert.hasAssertions();", false],
    "snapshot.test.ts": ["assert(1).toMatchInlineSnapshot();", false],
    "behaviour.test.ts": [
      "assert(1).toBe(1); assert(1).toMatchInlineSnapshot();",
      true,
    ],
  } as const;
  const project = fixture(
    Object.fromEntries(
      Object.entries(cases).map(([name, [body]]) => [
        `tests/unit/${name}`,
        `import { test as check, expect as assert } from "bun:test"; check.each([1])("probe", () => { ${body} });\n`,
      ]),
    ),
  );
  try {
    const { exitCode, rules } = lintRules(project, "tests");
    expect(exitCode).not.toBe(0);
    for (const [name, [, valid]] of Object.entries(cases)) {
      const found = rules.get(name) ?? ["no report"];
      if (valid) expect(found).toEqual([]);
      else
        expect(found.some((rule) => rule.startsWith("local/require-"))).toBe(
          true,
        );
    }
  } finally {
    project.close();
  }
}, 90000);

test("[service-checks-a8c50a] real lint rejects lint violations", () => {
  const project = fixture({ "src/probe.ts": "const unused = 1;\n" });
  try {
    const result = project.run("run", "lint");
    expect(result.exitCode).not.toBe(0);
    expect(result.stdout.toString()).toContain("no-unused-vars");
  } finally {
    project.close();
  }
}, 90000);

// One tsc run checks every unsafe case in src, tests and the tooling folder,
// and a second one the clean source: a run per case is too slow on CI.
test("[service-checks-3b5dea] strict flags reject unsafe source, tests and tooling", () => {
  const unsafe = {
    "implicit-any": [
      "export function unsafe(value) { return value; }\n",
      "TS7006",
    ],
    "unchecked-index": ["export const unsafe: number = [1][2];\n", "TS2322"],
    "exact-optional": [
      "export const unsafe: { value?: string } = { value: undefined };\n",
      "TS2375",
    ],
  } as const;
  const paths = Object.entries(unsafe).flatMap(([name, [code, error]]) =>
    [`src/${name}.ts`, `tests/unit/${name}.test.ts`, `tooling/${name}.ts`].map(
      (path) => [path, code, error] as const,
    ),
  );
  const rejected = fixture(
    Object.fromEntries(paths.map(([path, code]) => [path, code])),
  );
  try {
    const result = rejected.run("run", "typecheck");
    expect(result.exitCode).not.toBe(0);
    const output = result.stdout.toString() + result.stderr.toString();
    for (const [path, , error] of paths) {
      expect(output).toMatch(
        new RegExp(`${path.replaceAll(".", "\\.")}\\(.*error ${error}`),
      );
    }
  } finally {
    rejected.close();
  }
  const project = fixture({
    "src/probe.ts": "export const value: number = 1;\n",
  });
  try {
    const result = project.run("run", "typecheck");
    expect(result.stderr.toString()).not.toContain("error TS");
    expect(result.exitCode).toBe(0);
    expect(readdirSync(`${project.root}/src`)).toEqual(["probe.ts"]);
  } finally {
    project.close();
  }
}, 90000);

test("[service-checks-a8c50a] lint rejects invalid formatting without rewriting", () => {
  const source = "export const value=1\n";
  const project = fixture({ "src/probe.ts": source });
  try {
    expect(project.run("run", "lint").exitCode).not.toBe(0);
    expect(readFileSync(`${project.root}/src/probe.ts`, "utf8")).toBe(source);
    expect(project.run("run", "format").exitCode).toBe(0);
    expect(project.run("run", "lint").exitCode).toBe(0);
  } finally {
    project.close();
  }
}, 90000);

test("[service-checks-cdc6fa] suites select independently and empty suites fail", () => {
  const project = fixture({
    "tests/unit/probe.test.ts":
      'import { expect, test } from "bun:test";\ntest("unit", () => { expect(1).toBe(1); });\n',
    "tests/integration/probe.test.ts":
      'import { expect, test } from "bun:test";\ntest("integration", () => { expect(1).toBe(2); });\n',
  });
  try {
    expect(project.run("run", "test:unit").exitCode).toBe(0);
    expect(project.run("run", "test:integration").exitCode).not.toBe(0);
  } finally {
    project.close();
  }
  const empty = fixture({ "src/probe.ts": "export const value = 1;\n" });
  try {
    expect(empty.run("run", "test:unit").exitCode).not.toBe(0);
    expect(empty.run("run", "test:integration").exitCode).not.toBe(0);
  } finally {
    empty.close();
  }
}, 30000);

// Lints each fixture file under src/ in one type-aware run and returns its
// findings by file name, each as "<rule> <message>".
function lintFindings(files: Record<string, string>): {
  exitCode: number;
  findings: Map<string, string>;
} {
  const project = fixture(
    Object.fromEntries(
      Object.entries(files).map(([name, code]) => [`src/${name}`, code]),
    ),
  );
  try {
    const run = project.run("--bun", "eslint", "-f", "json", "src");
    const findings = new Map<string, string>();
    for (const file of LintReport.parse(JSON.parse(run.stdout.toString()))) {
      findings.set(
        basename(file.filePath),
        file.messages
          .map(({ ruleId, message }) => `${ruleId ?? "-"} ${message}`)
          .join("\n"),
      );
    }
    return { exitCode: run.exitCode, findings };
  } finally {
    project.close();
  }
}

// Lints the rejected cases together and the clean rewrite alone. A case is
// "missed" when lint does not report its expected finding.
function lintCases(
  cases: Record<string, readonly [code: string, finding: string]>,
  clean: string,
): {
  exitCode: number;
  missed: string[];
  clean: string;
  cleanExitCode: number;
} {
  const { exitCode, findings } = lintFindings(
    Object.fromEntries(
      Object.entries(cases).map(([name, [code]]) => [name, code]),
    ),
  );
  const missed = Object.entries(cases)
    .filter(
      ([name, [, finding]]) => !(findings.get(name) ?? "").includes(finding),
    )
    .map(([name]) => `${name}: ${findings.get(name) ?? "no report"}`);
  const passed = lintFindings({ "clean.ts": clean });
  return {
    exitCode,
    missed,
    clean: passed.findings.get("clean.ts") ?? "no report",
    cleanExitCode: passed.exitCode,
  };
}

const rejectedThenClean = {
  exitCode: 1,
  missed: [],
  clean: "",
  cleanExitCode: 0,
};

test("[service-checks-3b5dea] strict flags reject missing returns, overrides, fallthrough and value type imports", () => {
  const cases = {
    "src/returns.ts": [
      "export function f(x: boolean): number | undefined {\n  if (x) {\n    return 1;\n  }\n}\n",
      "TS7030",
    ],
    "src/override.ts": [
      "class A {\n  m(): void {}\n}\nexport class B extends A {\n  m(): void {}\n}\n",
      "TS4114",
    ],
    "src/fallthrough.ts": [
      "export function g(n: number): number {\n  let r = 0;\n  switch (n) {\n    case 1:\n      r = 1;\n    case 2:\n      r = 2;\n  }\n  return r;\n}\n",
      "TS7029",
    ],
    "src/imports.ts": [
      'import { Thing } from "./thing";\nexport const thing: Thing = { id: 1 };\n',
      "TS1484",
    ],
  } as const;
  const project = fixture({
    ...Object.fromEntries(
      Object.entries(cases).map(([path, [code]]) => [path, code]),
    ),
    "src/thing.ts": "export type Thing = { id: number };\n",
  });
  try {
    const result = project.run("run", "typecheck");
    expect(result.exitCode).not.toBe(0);
    const output = result.stdout.toString() + result.stderr.toString();
    for (const [path, [, code]] of Object.entries(cases)) {
      expect(output).toContain(`${path}(`);
      expect(output).toMatch(new RegExp(`${path}\\(.*error ${code}`));
    }
  } finally {
    project.close();
  }
}, 90000);

test("[service-checks-7b0f32] type-aware lint rejects unsafe code", () => {
  expect(
    lintCases(
      {
        "floating.ts": [
          "export function run(): void {\n  Promise.resolve(1);\n}\n",
          "@typescript-eslint/no-floating-promises",
        ],
        "any.ts": [
          'export const v: number = JSON.parse("1");\n',
          "@typescript-eslint/no-unsafe-assignment",
        ],
        "assertion.ts": [
          "export function s(v: string | number): string {\n  return v as string;\n}\n",
          "@typescript-eslint/no-unsafe-type-assertion",
        ],
        "non-null.ts": [
          "export function n(v: string | undefined): string {\n  return v!;\n}\n",
          "@typescript-eslint/no-non-null-assertion",
        ],
        "truthy.ts": [
          "export function b(text: string): number {\n  if (text) {\n    return 1;\n  }\n  return 0;\n}\n",
          "@typescript-eslint/strict-boolean-expressions",
        ],
        "switch.ts": [
          'export function w(v: "a" | "b"): number {\n  switch (v) {\n    case "a":\n      return 1;\n  }\n  return 0;\n}\n',
          "@typescript-eslint/switch-exhaustiveness-check",
        ],
        "loose.ts": [
          "export function e(v: number): boolean {\n  return v == 1;\n}\n",
          "eqeqeq",
        ],
      },
      [
        "export async function run(): Promise<number> {",
        "  return await Promise.resolve(1);",
        "}",
        'const parsed: unknown = JSON.parse("1");',
        'export const v: number = typeof parsed === "number" ? parsed : 0;',
        "export function s(v: string | number): string {",
        '  return typeof v === "string" ? v : String(v);',
        "}",
        "export function n(v: string | undefined): string {",
        '  return v ?? "";',
        "}",
        "export function b(text: string): number {",
        '  if (text !== "") {',
        "    return 1;",
        "  }",
        "  return 0;",
        "}",
        'export function w(v: "a" | "b"): number {',
        "  switch (v) {",
        '    case "a":',
        "      return 1;",
        '    case "b":',
        "      return 2;",
        "  }",
        "}",
        "export function e(v: number): boolean {",
        "  return v === 1;",
        "}",
        "",
      ].join("\n"),
    ),
  ).toEqual(rejectedThenClean);
}, 90000);

test("[service-checks-2fe7bd] lint requires declared boundary types", () => {
  expect(
    lintCases(
      {
        "exported.ts": [
          "export function f(n: number) {\n  return n;\n}\n",
          "@typescript-eslint/explicit-module-boundary-types",
        ],
        "named.ts": [
          "function g(n: number) {\n  return n;\n}\nexport const value: number = g(1);\n",
          "@typescript-eslint/explicit-function-return-type",
        ],
      },
      [
        "export function f(n: number): number {",
        "  return n;",
        "}",
        "function g(n: number): number {",
        "  return n;",
        "}",
        "export const value: number[] = [g(1)].map((n) => n * 2);",
        "",
      ].join("\n"),
    ),
  ).toEqual(rejectedThenClean);
}, 90000);

// The suppression comments these fixtures lint, assembled so that
// bin/check-lint-disables.sh does not count fixture text as a suppression.
const DISABLE = ["eslint", "disable-next-line"].join("-");
const EXPECT_ERROR = ["@ts", "expect-error"].join("-");

test("[service-checks-d62714] lint rejects unexplained suppressions", () => {
  expect(
    lintCases(
      {
        "unlimited.ts": [
          `// ${DISABLE}\nexport const v: number = 1;\n`,
          "eslint-comments/no-unlimited-disable",
        ],
        "no-reason.ts": [
          `// ${DISABLE} @typescript-eslint/no-explicit-any\nexport const v: any = 1;\n`,
          "eslint-comments/require-description",
        ],
        "unused.ts": [
          `// ${DISABLE} @typescript-eslint/no-explicit-any -- probe\nexport const v: number = 1;\n`,
          `Unused ${["eslint", "disable"].join("-")} directive`,
        ],
        "ts-ignore.ts": [
          "// @ts-ignore\nexport const v: number = 1;\n",
          "@typescript-eslint/ban-ts-comment",
        ],
        "expect-error.ts": [
          `// ${EXPECT_ERROR}\nexport const v: number = "1";\n`,
          "@typescript-eslint/ban-ts-comment",
        ],
      },
      [
        `// ${DISABLE} @typescript-eslint/no-explicit-any -- probe`,
        "export const v: any = 1;",
        `// ${EXPECT_ERROR} -- probe`,
        'export const w: number = "1";',
        "",
      ].join("\n"),
    ),
  ).toEqual(rejectedThenClean);
}, 90000);
