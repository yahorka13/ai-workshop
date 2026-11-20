// Renders the ui's typed GraphQL documents from the backend's contract, and the
// comparison the read-only check relies on. Generation reads only the schema
// file and the operations under src/services/graphql/: no network, no stack.
import { existsSync, readFileSync, readdirSync } from "node:fs";
import { join, relative } from "node:path";
import { generate } from "@graphql-codegen/cli";
import { preset } from "@graphql-codegen/client-preset";
import { z } from "zod";

const generatedNotice = [
  "Generated file: do not edit it by hand.",
  "Change its source and run bin/contracts generate.",
] as const;

// The notice as line comments in the target language, e.g. `//` for TypeScript.
export function commentNotice(prefix: string): string {
  return generatedNotice.map((line) => `${prefix} ${line}\n`).join("");
}

// The folder the typed documents are generated into, owned by generation.
export const graphqlTypesRoot = "src/services/graphql/generated";

// The backend schema as bin/check and bin/contracts mount it.
export function contractSchemaPath(
  env: Record<string, string | undefined>,
): string {
  return `${env.CONTRACTS_DIR ?? "/contracts"}/backend/schema.graphql`;
}

const GeneratedFiles = z.array(
  z.object({ filename: z.string(), content: z.string() }),
);

// Typed documents for every operation under src/services/graphql/ in `cwd`,
// keyed by their path under graphqlTypesRoot. The wire-convention scalars stay
// strings so exact values are never coerced to number or Date.
export async function renderGraphQLTypes(
  schemaFile: string,
  cwd: string,
): Promise<Record<string, string>> {
  if (!existsSync(schemaFile))
    throw new Error(
      `${schemaFile} not found: declare backend in consumes.txt and run through bin/check or bin/contracts generate, which mount its contracts.`,
    );
  const outputs: unknown = await generate(
    {
      cwd,
      silent: true,
      schema: schemaFile,
      documents: ["src/services/graphql/**/*.ts", `!${graphqlTypesRoot}/**`],
      generates: {
        [`${graphqlTypesRoot}/`]: {
          // The module, not its name: a name resolves from `cwd`.
          preset,
          presetConfig: { fragmentMasking: false },
          config: {
            scalars: {
              Date: "string",
              DateTime: "string",
              Decimal: "string",
              BigInt: "string",
            },
            enumsAsTypes: true,
            strictScalars: true,
            useTypeImports: true,
          },
        },
      },
    },
    false,
  );
  return Object.fromEntries(
    GeneratedFiles.parse(outputs).map((output) => [
      relative(join(cwd, graphqlTypesRoot), join(cwd, output.filename)),
      `${commentNotice("//")}\n${output.content.trimEnd()}\n`,
    ]),
  );
}

// Relative paths of every file under `root`; an absent root has none.
function files(root: string): string[] {
  if (!existsSync(root)) return [];
  return readdirSync(root, { recursive: true, withFileTypes: true })
    .filter((entry) => entry.isFile())
    .map((entry) =>
      relative(root, join(entry.parentPath, entry.name)).replaceAll("\\", "/"),
    )
    .sort();
}

export type TreeDifference = {
  changed: string[];
  missing: string[];
  extra: string[];
};

// Byte comparison of a freshly generated tree with the committed one. `missing`
// files were generated but are not committed; `extra` ones are committed but
// no longer generated.
export function compareTrees(
  expectedDir: string,
  actualDir: string,
): TreeDifference {
  const expected = files(expectedDir);
  const actual = files(actualDir);
  const present = new Set(actual);
  const wanted = new Set(expected);
  return {
    changed: expected.filter(
      (path) =>
        present.has(path) &&
        !readFileSync(join(expectedDir, path)).equals(
          readFileSync(join(actualDir, path)),
        ),
    ),
    missing: expected.filter((path) => !present.has(path)),
    extra: actual.filter((path) => !wanted.has(path)),
  };
}
