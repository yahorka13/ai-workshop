import { expect, test } from "bun:test";
import { Linter } from "eslint";
import ts from "typescript-eslint";
import policy from "../../tooling/test-policy.mjs";

function diagnostics(
  source: string,
  additionalMatchers: string[] = [],
): Linter.LintMessage[] {
  return new Linter().verify(
    source,
    [
      {
        files: ["**/*.ts"],
        languageOptions: { parser: ts.parser },
        plugins: { local: policy },
        rules: {
          "local/require-assertion":
            additionalMatchers.length > 0
              ? ["error", { additionalMatchers }]
              : "error",
          "local/require-behavioral-assertion":
            additionalMatchers.length > 0
              ? ["error", { additionalMatchers }]
              : "error",
        },
      },
    ],
    { filename: "probe.test.ts" },
  );
}

test("[service-checks-f37672] variable titles cannot bypass assertion policy", () => {
  expect(
    diagnostics(
      'import { test } from "bun:test"; const title = "probe"; test(title, () => {});',
    ).map((item) => item.ruleId),
  ).toContain("local/require-assertion");
});

for (const builder of ["skipIf(false)", "if(true)", "todoIf(false)"]) {
  test(`[service-checks-b489e4] conditional builder ${builder} preserves assertions`, () => {
    expect(
      diagnostics(
        `import { test, expect } from "bun:test"; const title = "probe"; test.${builder}(title, () => expect(1).toBe(1));`,
      ),
    ).toEqual([]);
    expect(
      diagnostics(
        `import { test } from "bun:test"; const title = "probe"; test.${builder}(title, () => {});`,
      ).map((item) => item.ruleId),
    ).toContain("local/require-assertion");
  });
}

test("[service-checks-f37672] [service-checks-1a0230] inherited object methods are not assertions", () => {
  expect(
    diagnostics(
      'import { test, expect } from "bun:test"; test("probe", () => expect(1).toString());',
    ).map((item) => item.ruleId),
  ).toContain("local/require-assertion");
  expect(
    diagnostics(
      'import { test, expect } from "bun:test"; test("probe", () => { expect(1).toMatchSnapshot(); expect(1).toString(); });',
    ).map((item) => item.ruleId),
  ).toContain("local/require-behavioral-assertion");
});

test("[service-checks-b489e4] custom matchers require an explicit local allowlist", () => {
  const source =
    'import { test, expect } from "bun:test"; test("probe", () => expect(1).toBeCustom());';
  expect(diagnostics(source).map((item) => item.ruleId)).toContain(
    "local/require-assertion",
  );
  expect(diagnostics(source, ["toBeCustom"])).toEqual([]);
});

for (const body of [
  "",
  "expect(1)",
  "expect.hasAssertions()",
  "expect.assertions(1)",
  "const helper = () => expect(1).toBe(1)",
  'test("nested", () => expect(1).toBe(1))',
  "helper()",
  "const expect = () => ({ toBe() {} }); expect(1).toBe(1)",
]) {
  test(`[service-checks-f37672] rejects missing direct assertion: ${body}`, () => {
    const result = diagnostics(
      `import { test, expect } from "bun:test"; test("probe", () => { ${body} });`,
    );
    expect(
      result.some((item) => item.ruleId === "local/require-assertion"),
    ).toBe(true);
  });
}

for (const form of [
  "test",
  "it",
  "test.only",
  "test.skip",
  "test.each([1])",
  "test.only.each([1])",
  "test.each([1]).only",
]) {
  test(`[service-checks-f37672] enforces modified test form ${form}`, () => {
    const result = diagnostics(
      `import { test, it, expect } from "bun:test"; ${form}("probe", () => {});`,
    );
    expect(result.map((item) => item.ruleId)).toContain(
      "local/require-assertion",
    );
  });
}

for (const matcher of [
  "toMatchSnapshot",
  "toMatchInlineSnapshot",
  "toThrowErrorMatchingSnapshot",
  "toThrowErrorMatchingInlineSnapshot",
]) {
  test(`[service-checks-1a0230] rejects snapshot-only ${matcher}`, () => {
    const result = diagnostics(
      `import { test, expect } from "bun:test"; test("probe", async () => { await expect(1).resolves.not.${matcher}(); });`,
    );
    expect(result.map((item) => item.ruleId)).toEqual([
      "local/require-behavioral-assertion",
    ]);
  });
}

for (const body of [
  "expect(1).toBe(1)",
  "expect(1).not.toBe(2); expect(1).toMatchSnapshot()",
  "await expect(Promise.resolve(1)).resolves.toBe(1)",
  "if (true) { expect(1).toBe(1) }",
]) {
  test(`[service-checks-b489e4] accepts behavioral assertion ${body}`, () => {
    expect(
      diagnostics(
        `import { test, expect } from "bun:test"; test("probe", async () => { ${body} });`,
      ),
    ).toEqual([]);
  });
}

test("[service-checks-b489e4] resolves imported aliases and ignores unrelated calls", () => {
  expect(
    diagnostics(
      'import { test as check, expect as assert } from "bun:test"; check.each([1])("probe", () => assert(1).toBe(1));',
    ),
  ).toEqual([]);
  expect(
    diagnostics(
      'import { test } from "some-library"; test("probe", () => {});',
    ),
  ).toEqual([]);
});

test("[service-checks-f37672] rejects opaque callbacks and hook-only assertions", () => {
  expect(
    diagnostics(
      'import { test, expect, beforeEach } from "bun:test"; beforeEach(() => expect(1).toBe(1)); test("probe", () => {});',
    ).map((item) => item.ruleId),
  ).toContain("local/require-assertion");
  expect(
    diagnostics(
      'import { test } from "bun:test"; test("probe", callback);',
    ).map((item) => item.ruleId),
  ).toContain("local/require-assertion");
});
