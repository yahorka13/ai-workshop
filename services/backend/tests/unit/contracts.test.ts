import { afterEach, expect, test } from "bun:test";
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { GraphQLObjectType, GraphQLSchema, GraphQLString } from "graphql";
import { commentNotice, compareTrees } from "../../src/contracts/files";
import { buildContract, renderSchema } from "../../src/contracts/graphql";
import { schema } from "../../src/graphql/schema";

test("[contracts-ed0454] the rendered SDL starts with the notice and ends with one newline", () => {
  const rendered = renderSchema(schema);
  expect(rendered.startsWith(commentNotice("#"))).toBe(true);
  expect(rendered).toContain("bin/contracts generate");
  expect(rendered).toEndWith("}\n");
  expect(rendered).not.toEndWith("\n\n");
});

test("the notice is one comment line per sentence", () => {
  expect(commentNotice("#")).toBe(
    "# Generated file: do not edit it by hand.\n# Change its source and run bin/contracts generate.\n",
  );
});

test("[contracts-d364e3] types are sorted: Health before Query", () => {
  const rendered = renderSchema(schema);
  expect(rendered.indexOf("type Health {")).toBeGreaterThan(0);
  expect(rendered.indexOf("type Health {")).toBeLessThan(
    rendered.indexOf("type Query {"),
  );
  expect(rendered).toContain("  health: Health!\n");
});

test("[contracts-a7e939] a schema that does not build is refused, naming the error", () => {
  expect(() =>
    buildContract(() => {
      throw new Error("Ref Missing has not been implemented");
    }),
  ).toThrow("schema.graphql: invalid GraphQL schema:\n- Ref Missing");
  expect(buildContract(() => schema)).toBe(schema);
  const cause = new Error("Ref Missing has not been implemented");
  let thrown: unknown;
  try {
    buildContract(() => {
      throw cause;
    });
  } catch (error) {
    thrown = error;
  }
  expect(thrown instanceof Error && thrown.cause).toBe(cause);
});

test("[contracts-a7e939] a schema that fails validation is refused, naming the error", () => {
  const invalid = new GraphQLSchema({
    query: new GraphQLObjectType({
      name: "Query",
      fields: { __bad: { type: GraphQLString } },
    }),
  });
  expect(() => renderSchema(invalid)).toThrow(
    /schema\.graphql: invalid GraphQL schema:\n- .*__bad/,
  );
});

let roots: string[] = [];
afterEach(() => {
  for (const root of roots) rmSync(root, { recursive: true, force: true });
  roots = [];
});

function tree(files: Record<string, string>): string {
  const root = mkdtempSync(join(tmpdir(), "tree-"));
  roots.push(root);
  for (const [path, text] of Object.entries(files)) {
    mkdirSync(join(root, path, ".."), { recursive: true });
    writeFileSync(join(root, path), text);
  }
  return root;
}

test("comparing trees names changed, missing and extra files byte for byte", () => {
  const expected = tree({ "a.graphql": "a\n", "b/c.json": "c\n", d: "d\n" });
  const actual = tree({ "a.graphql": "a\r\n", d: "d\n", "stray.txt": "" });
  expect(compareTrees(expected, actual)).toEqual({
    changed: ["a.graphql"],
    missing: ["b/c.json"],
    extra: ["stray.txt"],
  });
  expect(compareTrees(expected, join(actual, "absent"))).toEqual({
    changed: [],
    missing: ["a.graphql", "b/c.json", "d"],
    extra: [],
  });
});
