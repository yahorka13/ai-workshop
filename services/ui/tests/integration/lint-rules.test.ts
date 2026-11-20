import { expect, test } from "bun:test";
import { fixture } from "../fixtures";
import { LintReport } from "../support/lint-report";

// A test that runs type-aware ESLint or tsc in a fixture gets 90 s: at least
// three times its time on CI, so a slower runner passes and a hang still fails.

// Lints the given paths of a scratch copy of the service's config and tooling
// in one ESLint run (type-aware linting is slow), and returns each path's
// messages as "<rule>: <message>".
const lint = (
  files: Record<string, string>,
  ...paths: string[]
): { exitCode: number; messages: Record<string, string[]> } => {
  const project = fixture(files);
  try {
    const run = project.run("--bun", "eslint", "--format", "json", ...paths);
    const report = LintReport.parse(JSON.parse(run.stdout.toString()));
    const messages: Record<string, string[]> = {};
    for (const path of paths)
      messages[path] =
        report
          .find((file) => file.filePath.endsWith(`/${path}`))
          ?.messages.map(
            (message) => `${String(message.ruleId)}: ${message.message}`,
          ) ?? [];
    return { exitCode: run.exitCode, messages };
  } finally {
    project.close();
  }
};

const component = (name: string, className: string): string =>
  `import type { ReactElement } from "react";\n\nexport function ${name}(): ReactElement {\n  return <div className="${className}" />;\n}\n`;

test("[design-system-e11a0c] a hex colour in an arbitrary class fails lint", () => {
  const hex = "src/components/Hex.tsx";
  const token = "src/components/Token.tsx";
  const run = lint(
    {
      [hex]: component("Hex", "bg-[#ffffff] p-2"),
      [token]: component("Token", "bg-background p-2"),
    },
    hex,
    token,
  );
  expect(run.exitCode).not.toBe(0);
  expect(run.messages[hex]?.join("\n")).toContain("colours/no-hex-classes");
  expect(run.messages[token]).toEqual([]);
}, 90000);

const page = (name: string, body: string): string =>
  `import type { ReactElement } from "react";\n${body}\nexport function ${name}(): ReactElement {\n  return <main />;\n}\n`;

test("[service-checks-07c2e1] a page importing another page fails lint", () => {
  const cross = "src/pages/home/HomePage.tsx";
  const shared = "src/pages/about/AboutPage.tsx";
  const run = lint(
    {
      "src/pages/not-found/NotFoundPage.tsx": page("NotFoundPage", ""),
      "src/components/Shared.tsx": page("Shared", ""),
      [cross]: page(
        "HomePage",
        'export { NotFoundPage } from "@/pages/not-found/NotFoundPage";\n',
      ),
      [shared]: page(
        "AboutPage",
        'export { Shared } from "@/components/Shared";\n',
      ),
    },
    cross,
    shared,
  );
  expect(run.exitCode).not.toBe(0);
  expect(run.messages[cross]?.join("\n")).toContain(
    "pages/home must not import from pages/not-found",
  );
  expect(run.messages[shared]).toEqual([]);
}, 90000);
