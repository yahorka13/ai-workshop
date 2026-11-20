import { expect, test } from "bun:test";
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import {
  commentNotice,
  compareTrees,
  contractSchemaPath,
  graphqlTypesRoot,
  renderGraphQLTypes,
} from "../../tooling/contracts-render";

function tree(files: Record<string, string>): string {
  const root = mkdtempSync(join(tmpdir(), "ui-tree-"));
  for (const [path, text] of Object.entries(files)) {
    mkdirSync(join(root, path, ".."), { recursive: true });
    writeFileSync(join(root, path), text);
  }
  return root;
}

test("the schema path follows CONTRACTS_DIR, else /contracts", () => {
  expect(contractSchemaPath({})).toBe("/contracts/backend/schema.graphql");
  expect(contractSchemaPath({ CONTRACTS_DIR: "/x" })).toBe(
    "/x/backend/schema.graphql",
  );
});

test("the notice is two comment lines", () => {
  expect(commentNotice("#")).toBe(
    "# Generated file: do not edit it by hand.\n# Change its source and run bin/contracts generate.\n",
  );
});

test("trees compare by bytes, naming changed, missing and extra files", () => {
  const expected = tree({ "a.ts": "a", "sub/b.ts": "b", "c.ts": "c" });
  const actual = tree({ "a.ts": "a", "sub/b.ts": "B", "d.ts": "d" });
  try {
    expect(compareTrees(expected, actual)).toEqual({
      changed: ["sub/b.ts"],
      missing: ["c.ts"],
      extra: ["d.ts"],
    });
    expect(compareTrees(expected, join(actual, "absent"))).toEqual({
      changed: [],
      missing: ["a.ts", "c.ts", "sub/b.ts"],
      extra: [],
    });
  } finally {
    rmSync(expected, { recursive: true, force: true });
    rmSync(actual, { recursive: true, force: true });
  }
});

test("the typed documents render from a schema and the operations", async () => {
  const cwd = tree({
    "schema.graphql":
      "scalar DateTime\ntype Query { now: DateTime!, ok: Boolean! }\n",
    "src/services/graphql/now.ts":
      'import { graphql } from "./generated";\nexport const Now = graphql(`query Now { now ok }`);\n',
  });
  try {
    const rendered = await renderGraphQLTypes(join(cwd, "schema.graphql"), cwd);
    expect(Object.keys(rendered).sort()).toEqual([
      "gql.ts",
      "graphql.ts",
      "index.ts",
    ]);
    expect(rendered["graphql.ts"]).toStartWith(commentNotice("//"));
    expect(rendered["graphql.ts"]).toContain(
      "export type NowQuery = { now: string, ok: boolean };",
    );
    expect(graphqlTypesRoot).toBe("src/services/graphql/generated");
    const missing: unknown = await renderGraphQLTypes(
      join(cwd, "missing.graphql"),
      cwd,
    ).catch((error: unknown) => error);
    expect(missing).toBeInstanceOf(Error);
    expect(String(missing)).toContain("missing.graphql not found");
  } finally {
    rmSync(cwd, { recursive: true, force: true });
  }
});
