// Generate or check the backend's contracts. The contract is rendered into a
// scratch directory; `generate` then replaces contracts/ with it, and `check`
// only compares the two.
import { cpSync, mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { compareTrees } from "../src/contracts/files";
import { buildContract, renderSchema } from "../src/contracts/graphql";

const usage = `Usage: bun tooling/contracts.ts <generate|check>

  generate  Render the backend's contracts and replace contracts/ with the
            result.
  check     Render them into a temporary folder and fail, writing nothing,
            when a committed file differs, is missing or is not generated.

The backend owns contracts/: contracts/schema.graphql, the GraphQL schema of
src/graphql/schema.ts rendered by src/contracts/. Generated files are never
edited by hand: change the source, then run bin/contracts generate from the
repository root, which also regenerates every service that declares the
backend in its consumes.txt. Package scripts: bun run contracts:generate,
bun run contracts.`;

const ROOT = "contracts";

async function render(): Promise<string> {
  const rendered = mkdtempSync(join(tmpdir(), "backend-contracts-"));
  try {
    // Imported here, so a schema that throws while it builds is reported.
    const { schema } = await import("../src/graphql/schema");
    const text = renderSchema(buildContract(() => schema));
    mkdirSync(join(rendered, ROOT));
    writeFileSync(join(rendered, ROOT, "schema.graphql"), text);
    return rendered;
  } catch (error) {
    rmSync(rendered, { recursive: true, force: true });
    throw error;
  }
}

function generate(rendered: string): number {
  rmSync(ROOT, { recursive: true, force: true });
  cpSync(join(rendered, ROOT), ROOT, { recursive: true });
  console.log(`generated: ${ROOT}`);
  return 0;
}

function check(rendered: string): number {
  const { changed, missing, extra } = compareTrees(join(rendered, ROOT), ROOT);
  const problems = [
    ...changed.map((path) => `changed: ${ROOT}/${path}`),
    ...missing.map((path) => `missing: ${ROOT}/${path}`),
    ...extra.map((path) => `not generated: ${ROOT}/${path}`),
  ];
  if (problems.length === 0) {
    console.log(`contracts are current: ${ROOT}`);
    return 0;
  }
  console.error(
    `Generated files do not match their source:\n${problems
      .map((problem) => `  ${problem}`)
      .join("\n")}\nRun bin/contracts generate and commit the result.`,
  );
  return 1;
}

const commands: Record<string, (rendered: string) => number> = {
  generate,
  check,
};
const [command, ...rest] = process.argv.slice(2);
if (command === "--help" || command === "-h") {
  console.log(usage);
  process.exit(0);
}
const run = command === undefined ? undefined : commands[command];
if (!run || rest.length > 0) {
  console.error(usage);
  process.exit(2);
}
let rendered: string;
try {
  rendered = await render();
} catch (error) {
  console.error(error instanceof Error ? error.message : String(error));
  process.exit(1);
}
try {
  process.exitCode = run(rendered);
} finally {
  rmSync(rendered, { recursive: true, force: true });
}
