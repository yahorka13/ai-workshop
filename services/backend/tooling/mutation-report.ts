import { existsSync, readFileSync } from "node:fs";
import { z } from "zod";

// What bin/mutate reads from Stryker's mutation.json (mutation-testing-report-schema):
// each file's source and its mutants, positions 1-based with an exclusive end.
const position = z.object({ line: z.number().int(), column: z.number().int() });
const reportSchema = z.object({
  files: z.record(
    z.string(),
    z.object({
      source: z.string(),
      mutants: z.array(
        z.object({
          id: z.string(),
          mutatorName: z.string(),
          replacement: z.string().optional(),
          status: z.string(),
          location: z.object({ start: position, end: position }),
        }),
      ),
    }),
  ),
});

export type MutationReport = z.infer<typeof reportSchema>;
export type Mode = "changed" | "full";

export const parseReport = (value: unknown): MutationReport =>
  reportSchema.parse(value);

/** A run's report; a run that found no mutant to test writes none. */
export const readReport = (path: string): MutationReport =>
  existsSync(path)
    ? parseReport(JSON.parse(readFileSync(path, "utf8")))
    : { files: {} };

// Migrations hold SQL and snapshots, not code a test can kill a mutant in; the
// entry module starts the server when Stryker's runner imports it.
const MIGRATIONS = "src/db/migrations/";
const ENTRY = "src/index.ts";

/** Source bin/mutate mutates: the service's own TypeScript under src/. */
export const inScope = (path: string): boolean =>
  path.startsWith("src/") &&
  path.endsWith(".ts") &&
  !path.startsWith(MIGRATIONS) &&
  path !== ENTRY;

const DETECTED = new Set(["Killed", "Timeout"]);
const UNDETECTED = new Set(["Survived", "NoCoverage"]);
const COUNTED = ["Killed", "Timeout", "Survived", "NoCoverage"];

const cell = (code: string): string =>
  `\`${code.replaceAll("|", "\\|").replaceAll("`", "'")}\``;

// Code that may span lines as one cell: its first line, then … when there is more.
function firstLine(code: string): string {
  const [first = "", ...rest] = code.split("\n");
  return rest.length > 0 ? `${cell(first)} …` : cell(first);
}

function original(
  source: string,
  {
    start,
    end,
  }: MutationReport["files"][string]["mutants"][number]["location"],
): string {
  const line = source.split("\n")[start.line - 1] ?? "";
  if (end.line === start.line)
    return cell(line.slice(start.column - 1, end.column - 1));
  return `${cell(line.slice(start.column - 1))} …`;
}

/**
 * The markdown summary of a run, and how many mutants fail it: a changed run
 * fails on every survived or uncovered mutant, a full run on none.
 */
export function summarize(
  report: MutationReport,
  mode: Mode,
): { markdown: string; failing: number } {
  const counts = new Map<string, number>();
  const rows: string[] = [];
  const files = Object.entries(report.files).sort(([a], [b]) =>
    a.localeCompare(b),
  );
  for (const [path, file] of files) {
    const mutants = file.mutants.toSorted(
      (a, b) => a.location.start.line - b.location.start.line,
    );
    for (const mutant of mutants) {
      counts.set(mutant.status, (counts.get(mutant.status) ?? 0) + 1);
      if (!UNDETECTED.has(mutant.status)) continue;
      rows.push(
        `| ${path}:${String(mutant.location.start.line)} | ${mutant.mutatorName} | ${original(file.source, mutant.location)} → ${firstLine(mutant.replacement ?? "")} | ${mutant.status} |`,
      );
    }
  }
  const valid = COUNTED.reduce(
    (sum, status) => sum + (counts.get(status) ?? 0),
    0,
  );
  if (valid === 0) return { markdown: "No mutants to report.\n", failing: 0 };
  const detected = [...DETECTED].reduce(
    (sum, s) => sum + (counts.get(s) ?? 0),
    0,
  );
  const lines = [
    `Mutation score: ${((detected / valid) * 100).toFixed(2)}%`,
    "",
    COUNTED.map(
      (status) => `${status}: ${String(counts.get(status) ?? 0)}`,
    ).join(" · "),
  ];
  if (rows.length > 0)
    lines.push(
      "",
      "| Where | Mutator | Original → mutant | Status |",
      "|---|---|---|---|",
      ...rows,
    );
  return {
    markdown: `${lines.join("\n")}\n`,
    failing: mode === "changed" ? rows.length : 0,
  };
}
