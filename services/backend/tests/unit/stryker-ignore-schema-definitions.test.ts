import { expect, test } from "bun:test";
import {
  isSchemaSetting,
  strykerPlugins,
} from "../../tooling/stryker-ignore-schema-definitions.mjs";

// Minimal Babel nodes and paths: each path knows its node, its parent path
// and its key there.
type Node = { type: string } & Record<string, unknown>;
type Path = {
  node: Node;
  parentPath: Path | null;
  key: string | number | null;
  listKey?: string;
};

const id = (name: string): Node => ({ type: "Identifier", name });
const text = (value: string): Node => ({ type: "StringLiteral", value });
const member = (object: Node, name: string): Node => ({
  type: "MemberExpression",
  object,
  property: id(name),
});
const call = (callee: Node, args: Node[]): Node => ({
  type: "CallExpression",
  callee,
  arguments: args,
});
const object = (properties: Record<string, Node>): Node => ({
  type: "ObjectExpression",
  properties: Object.entries(properties).map(([key, value]) => ({
    type: "ObjectProperty",
    key: key.startsWith('"') ? text(key.slice(1, -1)) : id(key),
    value,
  })),
});
const arrow = (body: Node): Node => ({
  type: "ArrowFunctionExpression",
  params: [id("x")],
  body,
});
const compare: Node = {
  type: "BinaryExpression",
  operator: "===",
  left: id("status"),
  right: text("other"),
};

const isNode = (value: unknown): value is Node =>
  value !== null &&
  typeof value === "object" &&
  "type" in value &&
  typeof value.type === "string";

/** Every node in Stryker's order, and whether a mutant there is ignored:
    Stryker asks the ignorer on entering a node, unless an ancestor is
    already ignored, and then ignores that node's whole subtree. */
function mutated(root: Node): { node: Node; ignored: boolean }[] {
  const seen: { node: Node; ignored: boolean }[] = [];
  const enter = (path: Path, ignored: boolean): void => {
    const skip = ignored || isSchemaSetting(path);
    seen.push({ node: path.node, ignored: skip });
    for (const [key, value] of Object.entries(path.node)) {
      const children: unknown[] = Array.isArray(value) ? value : [value];
      children.forEach((child, index) => {
        if (isNode(child))
          enter(
            {
              node: child,
              parentPath: path,
              key: Array.isArray(value) ? index : key,
              ...(Array.isArray(value) ? { listKey: key } : {}),
            },
            skip,
          );
      });
    }
  };
  enter({ node: root, parentPath: null, key: null }, false);
  return seen;
}
const ignoredOf = (root: Node, node: Node): boolean | undefined =>
  mutated(root).find((entry) => entry.node === node)?.ignored;

const description = text("The viewer's name.");
const named = id("resolveName");

// builder.objectType("Viewer", { fields: (t) => ({ name: t.field({ ... }) }) })
const objectType = (field: Node): Node =>
  call(member(id("builder"), "objectType"), [
    text("Viewer"),
    object({
      fields: arrow(object({ name: call(member(id("t"), "field"), [field]) })),
    }),
  ]);

test("a definition whose resolvers are named functions is skipped whole", () => {
  const root = objectType(object({ description, resolve: named }));
  expect(ignoredOf(root, root)).toBe(true);
  expect(ignoredOf(root, description)).toBe(true);
  expect(ignoredOf(root, named)).toBe(true);
});

test("a chained builder call is skipped too", () => {
  const settings = object({ description });
  const root = call(
    member(call(member(id("builder"), "objectRef"), [text("X")]), "implement"),
    [settings],
  );
  expect(ignoredOf(root, root)).toBe(true);
  expect(ignoredOf(root, settings)).toBe(true);
});

test("an inline resolver's code is mutated, and so is everything around it", () => {
  for (const key of ["resolve", '"resolve"', "query", "subscribe", "load"]) {
    const resolver = arrow(compare);
    const root = objectType(object({ description, [key]: resolver }));
    expect(ignoredOf(root, root)).toBe(false);
    expect(ignoredOf(root, resolver)).toBe(false);
    expect(ignoredOf(root, compare)).toBe(false);
    // Its settings beside it are still skipped.
    expect(ignoredOf(root, description)).toBe(true);
  }
});

test("a resolver written as a method is mutated", () => {
  const method: Node = {
    type: "ObjectMethod",
    key: id("resolve"),
    params: [],
    body: compare,
  };
  const root = call(member(id("builder"), "objectType"), [
    { type: "ObjectExpression", properties: [method] },
  ]);
  expect(ignoredOf(root, root)).toBe(false);
  expect(ignoredOf(root, compare)).toBe(false);
});

test("a call on anything but the builder is mutated", () => {
  const root = call(member(id("client"), "query"), [object({ description })]);
  expect(ignoredOf(root, description)).toBe(false);
  expect(
    isSchemaSetting({ node: text("x"), parentPath: null, key: null }),
  ).toBe(false);
});

test("the plugin registers the schema-definitions ignorer with Stryker", () => {
  const [declared] = strykerPlugins;
  expect(declared?.kind).toBe("Ignore");
  expect(declared?.name).toBe("schema-definitions");
  const root = objectType(object({ description }));
  expect(
    declared?.value.shouldIgnore({ node: root, parentPath: null, key: null }),
  ).toBe(
    "Schema setting: Pothos reads it once per process; the contracts gate pins it",
  );
  expect(
    declared?.value.shouldIgnore({
      node: text("x"),
      parentPath: null,
      key: null,
    }),
  ).toBeUndefined();
});
