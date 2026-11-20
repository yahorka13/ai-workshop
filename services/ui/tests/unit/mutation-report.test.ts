import { expect, test } from "bun:test";
import { mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import {
  inScope,
  readReport,
  parseReport,
  summarize,
  type MutationReport,
} from "../../tooling/mutation-report";

type Mutant = MutationReport["files"][string]["mutants"][number];

const source =
  "export const n = (v: string) => /^\\d+$/.test(v);\nexport const x = 1;\n";

const mutant = (
  id: string,
  status: string,
  change: {
    line: number;
    start: number;
    end: number;
    mutatorName: string;
    replacement: string;
    endLine?: number;
  },
): Mutant => {
  const { line, start, end, mutatorName, replacement, endLine = line } = change;
  return {
    id,
    mutatorName,
    replacement,
    status,
    location: {
      start: { line, column: start },
      end: { line: endLine, column: end },
    },
  };
};

const report: MutationReport = parseReport({
  files: {
    "src/config.ts": {
      source,
      mutants: [
        mutant("1", "Killed", {
          line: 1,
          start: 33,
          end: 40,
          mutatorName: "Regex",
          replacement: "/\\d+$/",
        }),
        mutant("2", "Timeout", {
          line: 1,
          start: 33,
          end: 40,
          mutatorName: "Regex",
          replacement: "/^\\d$/",
        }),
        mutant("3", "Survived", {
          line: 1,
          start: 33,
          end: 40,
          mutatorName: "Regex",
          replacement: "/\\d+$/",
        }),
        mutant("4", "NoCoverage", {
          line: 2,
          start: 18,
          end: 19,
          mutatorName: "NumberLiteral",
          replacement: "0",
        }),
        mutant("5", "Ignored", {
          line: 2,
          start: 18,
          end: 19,
          mutatorName: "NumberLiteral",
          replacement: "2",
        }),
      ],
    },
  },
});

test("[service-checks-b6ed25] inScope keeps the app's source and leaves the entry module, stories, generated code and tests out", () => {
  expect(inScope("src/lib/next-path.ts")).toBe(true);
  expect(inScope("src/components/Notice.tsx")).toBe(true);
  expect(inScope("src/main.tsx")).toBe(false);
  expect(inScope("src/components/Notice.stories.tsx")).toBe(false);
  expect(inScope("src/services/graphql/generated/graphql.ts")).toBe(false);
  expect(inScope("src/i18n/i18next.d.ts")).toBe(false);
  expect(inScope("src/i18n/locales/en/common.json")).toBe(false);
  expect(inScope("tests/unit/lib/utils.test.ts")).toBe(false);
  expect(inScope("tooling/mutate.ts")).toBe(false);
});

test("a changed run fails on survived and uncovered mutants", () => {
  const { markdown, failing } = summarize(report, "changed");
  expect(failing).toBe(2);
  expect(markdown).toContain("Mutation score: 50.00%");
  expect(markdown).toContain(
    "| src/config.ts:1 | Regex | `/^\\d+$/` → `/\\d+$/` | Survived |",
  );
  expect(markdown).toContain(
    "| src/config.ts:2 | NumberLiteral | `1` → `0` | NoCoverage |",
  );
  expect(markdown).not.toContain("| Killed |");
  expect(markdown).not.toContain("| Timeout |");
  expect(markdown).not.toContain("| Ignored |");
});

test("a full run lists the same mutants without failing", () => {
  const { markdown, failing } = summarize(report, "full");
  expect(failing).toBe(0);
  expect(markdown).toContain("Mutation score: 50.00%");
  expect(markdown).toContain("| Survived |");
  expect(markdown).toContain("| NoCoverage |");
});

test("killed and timed-out mutants pass a changed run", () => {
  const killed = parseReport({
    files: {
      "src/a.ts": {
        source,
        mutants: [
          mutant("1", "Killed", {
            line: 1,
            start: 33,
            end: 40,
            mutatorName: "Regex",
            replacement: "x",
          }),
          mutant("2", "Timeout", {
            line: 1,
            start: 33,
            end: 40,
            mutatorName: "Regex",
            replacement: "y",
          }),
        ],
      },
    },
  });
  const { markdown, failing } = summarize(killed, "changed");
  expect(failing).toBe(0);
  expect(markdown).toContain("Mutation score: 100.00%");
  expect(markdown).toContain("Killed: 1 · Timeout: 1");
  expect(markdown).not.toContain("| src/a.ts");
});

test("survivors are listed by file and line", () => {
  const unordered = parseReport({
    files: {
      "src/b.ts": {
        source,
        mutants: [
          mutant("1", "Survived", {
            line: 2,
            start: 18,
            end: 19,
            mutatorName: "NumberLiteral",
            replacement: "0",
          }),
        ],
      },
      "src/a.ts": {
        source,
        mutants: [
          mutant("2", "Survived", {
            line: 2,
            start: 18,
            end: 19,
            mutatorName: "NumberLiteral",
            replacement: "0",
          }),
          mutant("3", "Survived", {
            line: 1,
            start: 33,
            end: 40,
            mutatorName: "Regex",
            replacement: "x",
          }),
        ],
      },
    },
  });
  const rows = summarize(unordered, "changed")
    .markdown.split("\n")
    .filter((line) => line.startsWith("| src/"))
    .map((line) => line.split(" | ")[0]);
  expect(rows).toEqual(["| src/a.ts:1", "| src/a.ts:2", "| src/b.ts:2"]);
});

test("a multi-line replacement shows its first line, keeping the row on one line", () => {
  const report = parseReport({
    files: {
      "src/d.ts": {
        source: "a &&\n  b;\n",
        mutants: [
          mutant("1", "Survived", {
            line: 1,
            start: 1,
            end: 4,
            mutatorName: "LogicalOperator",
            replacement: "a ||\n  b",
            endLine: 2,
          }),
        ],
      },
    },
  });
  const { markdown } = summarize(report, "changed");
  const row = markdown
    .split("\n")
    .find((line) => line.startsWith("| src/d.ts"));
  expect(row).toBe(
    "| src/d.ts:1 | LogicalOperator | `a &&` … → `a \\|\\|` … | Survived |",
  );
});

test("an empty report says there are no mutants", () => {
  const { markdown, failing } = summarize(
    parseReport({ files: {} }),
    "changed",
  );
  expect(failing).toBe(0);
  expect(markdown).toContain("No mutants");
});

test("a multi-line mutant shows its first line, and pipes cannot break the table", () => {
  const multi = parseReport({
    files: {
      "src/b.ts": {
        source: "const f = (a: number) =>\n  a || 1;\n",
        mutants: [
          mutant("1", "Survived", {
            line: 1,
            start: 11,
            end: 9,
            mutatorName: "ArrowFunction",
            replacement: "() => undefined",
            endLine: 2,
          }),
        ],
      },
    },
  });
  const { markdown } = summarize(multi, "changed");
  expect(markdown).toContain(
    "| src/b.ts:1 | ArrowFunction | `(a: number) =>` … → `() => undefined` | Survived |",
  );
  const piped = parseReport({
    files: {
      "src/c.ts": {
        source: "a || b;\n",
        mutants: [
          mutant("1", "Survived", {
            line: 1,
            start: 1,
            end: 7,
            mutatorName: "LogicalOperator",
            replacement: "a && b",
          }),
        ],
      },
    },
  });
  expect(summarize(piped, "changed").markdown).toContain("`a \\|\\| b`");
});

test("parseReport rejects a report that is not Stryker's", () => {
  expect(() => parseReport({})).toThrow();
  expect(() =>
    parseReport({
      files: { "src/a.ts": { source: "", mutants: [{ id: "1" }] } },
    }),
  ).toThrow();
});

test("a run that wrote no report, because it found no mutants, reads as empty", () => {
  const dir = mkdtempSync(join(tmpdir(), "mutation-report-"));
  expect(readReport(join(dir, "mutation.json"))).toEqual({ files: {} });
  writeFileSync(join(dir, "mutation.json"), JSON.stringify({ files: {} }));
  expect(
    summarize(readReport(join(dir, "mutation.json")), "changed").failing,
  ).toBe(0);
});
