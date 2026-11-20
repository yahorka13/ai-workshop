import { basename } from "node:path";
import { z } from "zod";
import type { Fixture } from "../fixtures";

export const LintReport = z.array(
  z.object({
    filePath: z.string(),
    messages: z.array(
      z.object({
        ruleId: z.string().nullable(),
        severity: z.number(),
        message: z.string(),
      }),
    ),
  }),
);

// Lints the given paths of a fixture in one ESLint run, since type-aware
// linting is slow, and returns its exit code and each file's rule ids by file
// name: an error as its rule id, a warning as "warning <rule id>", and "-" for
// a message without a rule.
export function lintRules(
  project: Fixture,
  ...paths: string[]
): { exitCode: number; rules: Map<string, string[]> } {
  const run = project.run("--bun", "eslint", "-f", "json", ...paths);
  return {
    exitCode: run.exitCode,
    rules: new Map(
      LintReport.parse(JSON.parse(run.stdout.toString())).map((file) => [
        basename(file.filePath),
        file.messages.map(({ ruleId, severity }) =>
          severity === 2 ? (ruleId ?? "-") : `warning ${ruleId ?? "-"}`,
        ),
      ]),
    ),
  };
}
