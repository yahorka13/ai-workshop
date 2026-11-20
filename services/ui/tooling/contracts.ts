// Generate or check the ui's typed GraphQL documents. They are rendered into a
// scratch directory that mirrors the service layout; `generate` then replaces
// the owned folder with its scratch copy, and `check` only compares the two.
import { cpSync, mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import {
  compareTrees,
  contractSchemaPath,
  graphqlTypesRoot,
  renderGraphQLTypes,
} from "./contracts-render";

const usage = `Usage: bun tooling/contracts.ts <generate|check>

  generate  Render the ui's typed GraphQL documents and replace the folder
            they own with the result.
  check     Render them into a temporary folder and fail, writing nothing,
            when a committed file differs, is missing or is not generated.

The ui consumes the backend's GraphQL contract, declared in consumes.txt and
read from $CONTRACTS_DIR/backend/schema.graphql (CONTRACTS_DIR defaults to
/contracts, where bin/check and bin/contracts mount it). It owns
${graphqlTypesRoot}/: typed documents for the operations under
src/services/graphql/. Generated files are never edited by hand: change the
operation or the backend source, then run bin/contracts generate from the
repository root.
Package scripts: bun run contracts:generate, bun run contracts.`;

async function render(): Promise<string> {
  const rendered = mkdtempSync(join(tmpdir(), "ui-contracts-"));
  try {
    const tree = await renderGraphQLTypes(
      contractSchemaPath(process.env),
      process.cwd(),
    );
    for (const [path, text] of Object.entries(tree)) {
      const file = join(rendered, graphqlTypesRoot, path);
      mkdirSync(dirname(file), { recursive: true });
      writeFileSync(file, text);
    }
    return rendered;
  } catch (error) {
    rmSync(rendered, { recursive: true, force: true });
    throw error;
  }
}

function generate(rendered: string): number {
  rmSync(graphqlTypesRoot, { recursive: true, force: true });
  cpSync(join(rendered, graphqlTypesRoot), graphqlTypesRoot, {
    recursive: true,
  });
  console.log(`generated: ${graphqlTypesRoot}`);
  return 0;
}

function check(rendered: string): number {
  const { changed, missing, extra } = compareTrees(
    join(rendered, graphqlTypesRoot),
    graphqlTypesRoot,
  );
  const problems = [
    ...changed.map((path) => `changed: ${graphqlTypesRoot}/${path}`),
    ...missing.map((path) => `missing: ${graphqlTypesRoot}/${path}`),
    ...extra.map((path) => `not generated: ${graphqlTypesRoot}/${path}`),
  ];
  if (problems.length === 0) {
    console.log(`contracts are current: ${graphqlTypesRoot}`);
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
