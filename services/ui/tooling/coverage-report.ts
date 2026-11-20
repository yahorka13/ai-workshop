import { relative, resolve } from "node:path";

function normalized(path: string): string {
  return relative(process.cwd(), resolve(path)).replaceAll("\\", "/");
}

type Counters = {
  functionsFound: number;
  functionsHit: number;
  linesFound: number;
  linesHit: number;
};

function reportProblems(
  records: readonly string[],
  tail: string | undefined,
): string[] {
  return (tail ?? "").trim() !== "" || records.length === 0
    ? ["Missing, empty or truncated coverage report"]
    : [];
}

function counter(lines: readonly string[], key: string): number {
  const values = lines.filter((line) => line.startsWith(`${key}:`));
  const [only] = values;
  if (values.length !== 1 || only === undefined) return NaN;
  const digits = only.slice(key.length + 1);
  return /^\d+$/.test(digits) ? Number(digits) : NaN;
}

function counters(lines: readonly string[]): Counters {
  return {
    functionsFound: counter(lines, "FNF"),
    functionsHit: counter(lines, "FNH"),
    linesFound: counter(lines, "LF"),
    linesHit: counter(lines, "LH"),
  };
}

function countersValid(counts: Counters): boolean {
  const { functionsFound, functionsHit, linesFound, linesHit } = counts;
  return (
    [functionsFound, functionsHit, linesFound, linesHit].every(
      Number.isSafeInteger,
    ) &&
    functionsHit <= functionsFound &&
    linesHit <= linesFound
  );
}

function dataValid(lines: readonly string[], counts: Counters): boolean {
  const data = lines.filter((line) => line.startsWith("DA:"));
  const validData = data.every((line) =>
    /^DA:[1-9]\d*,\d+(?:,[^,]+)?$/.test(line),
  );
  const covered = data.filter((line) => Number(line.split(",")[1]) > 0).length;
  const uniqueLines = new Set(data.map((line) => line.split(",")[0]));
  return (
    validData &&
    uniqueLines.size === data.length &&
    data.length === counts.linesFound &&
    covered === counts.linesHit
  );
}

function recordProblems(record: string, seen: Set<string>): string[] {
  const lines = record.trim().split("\n");
  const names = lines.filter((line) => line.startsWith("SF:"));
  const source = names[0]?.slice(3) ?? "";
  const name = normalized(source);
  if (names.length !== 1 || source === "" || seen.has(name))
    return [`Invalid or duplicate coverage source: ${name}`];
  seen.add(name);
  const counts = counters(lines);
  if (!countersValid(counts) || !dataValid(lines, counts))
    return [`Invalid coverage counters: ${name}`];
  const problems: string[] = [];
  if (counts.functionsHit !== counts.functionsFound)
    problems.push(`Uncovered function: ${name}`);
  if (counts.linesHit !== counts.linesFound)
    problems.push(`Uncovered line: ${name}`);
  return problems;
}

function missingSources(
  sourcePaths: readonly string[],
  seen: ReadonlySet<string>,
): string[] {
  return sourcePaths
    .filter((source) => !seen.has(normalized(source)))
    .map((source) => `Source missing from coverage: ${source}`);
}

export function validateCoverage(
  lcov: string,
  sourcePaths: readonly string[],
): string[] {
  const seen = new Set<string>();
  const records = lcov.split("end_of_record");
  const tail = records.pop();
  return [
    ...reportProblems(records, tail),
    ...records.flatMap((record) => recordProblems(record, seen)),
    ...missingSources(sourcePaths, seen),
  ];
}

// Declaration files hold no code. Stories are Storybook's examples, proven by
// the story checks and the gallery, not production code. Files under
// src/services/graphql/generated/ are typed documents emitted by
// bin/contracts generate: their source is a contract, which the contracts
// check covers.
export function coverageSources(paths: readonly string[]): string[] {
  return paths
    .filter((path) => {
      const posix = path.replaceAll("\\", "/");
      return (
        !posix.endsWith(".d.ts") &&
        !posix.endsWith(".stories.tsx") &&
        !posix.startsWith("src/services/graphql/generated/")
      );
    })
    .sort();
}

const transpiler = new Bun.Transpiler({ loader: "tsx" });

// A module that compiles to no code, such as one holding only types or an
// empty schema, has nothing to cover; Bun leaves it out of the report.
export function holdsCode(source: string): boolean {
  return (
    transpiler
      .transformSync(source)
      .replace(/^export \{\};$/m, "")
      .trim() !== ""
  );
}

const SUITES = ["tests/unit", "tests/integration"] as const;

// The suites that hold no test file. `bin/check` runs the coverage gate as its
// only test run, and `bun test` passes when one of two directories is empty, so
// an emptied suite has to fail here (the scripts already fail on their own).
export function missingSuites(files: readonly string[]): string[] {
  return SUITES.filter(
    (suite) =>
      !files.some(
        (file) =>
          file.replaceAll("\\", "/").startsWith(`${suite}/`) &&
          /[._](?:test|spec)\.[cm]?[jt]sx?$/.test(file),
      ),
  );
}

// The number of test workers: FACTORY_JOBS when bin/check passes it, else
// every core available to the container.
export function testWorkers(
  value: string | undefined,
  available: number,
): number {
  if (value === undefined || value === "") return available;
  if (!/^[1-9]\d*$/.test(value))
    throw new Error(`FACTORY_JOBS must be a positive integer, not ${value}`);
  return Number(value);
}
