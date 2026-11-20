import { expect, test } from "bun:test";
import {
  isClassName,
  strykerPlugins,
} from "../../tooling/stryker-ignore-class-names.mjs";

// Minimal Babel paths: each knows its node, its parent path and its key there.
type Node = Record<string, unknown> & { type: string };
type Path = {
  node: Node;
  parentPath: Path | null;
  key: string | number | null;
  listKey?: string;
};

// One step from a parent down to a child: the child node, its key in the
// parent and, for a list, the list's name.
type Step = [node: Node, key: string | number, listKey?: string];

// The path of the last node of `steps`, below `top`.
const down = (top: Node, ...steps: Step[]): Path =>
  steps.reduce<Path>(
    (parent, [node, key, listKey]) => ({
      node,
      parentPath: parent,
      key,
      ...(listKey === undefined ? {} : { listKey }),
    }),
    { node: top, parentPath: null, key: null },
  );

const id = (name: string): Node => ({ type: "Identifier", name });
const text = (value: string): Node => ({ type: "StringLiteral", value });
const template: Node = { type: "TemplateLiteral", quasis: [], expressions: [] };
const call = (callee: string): Node => ({
  type: "CallExpression",
  callee: id(callee),
});
const attribute = (name: string): Node => ({
  type: "JSXAttribute",
  name: { type: "JSXIdentifier", name },
});
const container: Node = { type: "JSXExpressionContainer" };
const and: Node = { type: "LogicalExpression", operator: "&&" };
const ternary: Node = { type: "ConditionalExpression" };
const object: Node = { type: "ObjectExpression" };
const property = (key: string): Node => ({
  type: "ObjectProperty",
  key: id(key),
});

test('[service-checks-e5eec4] className="a b" is skipped', () => {
  expect(
    isClassName(down(attribute("className"), [text("a b"), "value"])),
  ).toBe(true);
  expect(
    isClassName(
      down(
        attribute("className"),
        [container, "value"],
        [template, "expression"],
      ),
    ),
  ).toBe(true);
});

test("a string prop other than className is mutated", () => {
  expect(isClassName(down(attribute("title"), [text("Hi"), "value"]))).toBe(
    false,
  );
  expect(
    isClassName(
      down(
        attribute("aria-label"),
        [container, "value"],
        [template, "expression"],
      ),
    ),
  ).toBe(false);
});

test("each string argument of cn() is skipped, its condition is not", () => {
  const cn = call("cn");
  expect(isClassName(down(cn, [text("a"), 0, "arguments"]))).toBe(true);
  // cn("a", active && "b"): "b" is a class, active picks it
  expect(
    isClassName(down(cn, [and, 1, "arguments"], [text("b"), "right"])),
  ).toBe(true);
  expect(
    isClassName(down(cn, [and, 1, "arguments"], [id("active"), "left"])),
  ).toBe(false);
  expect(
    isClassName(down(cn, [and, 1, "arguments"], [text("on"), "left"])),
  ).toBe(false);
  // cn(open ? "a" : "b")
  expect(
    isClassName(down(cn, [ternary, 0, "arguments"], [text("a"), "consequent"])),
  ).toBe(true);
  expect(
    isClassName(down(cn, [ternary, 0, "arguments"], [text("x"), "test"])),
  ).toBe(false);
});

test("a className built with cn() skips through the attribute's container", () => {
  const top = attribute("className");
  expect(
    isClassName(
      down(
        top,
        [container, "value"],
        [call("cn"), "expression"],
        [text("a"), 0, "arguments"],
      ),
    ),
  ).toBe(true);
});

test("cva's base classes and its variants' classes are skipped", () => {
  const cva = call("cva");
  expect(isClassName(down(cva, [text("base"), 0, "arguments"]))).toBe(true);
  // cva("base", { variants: { size: { sm: "h-8" } } })
  expect(
    isClassName(
      down(
        cva,
        [object, 1, "arguments"],
        [property("variants"), 0, "properties"],
        [object, "value"],
        [property("size"), 0, "properties"],
        [object, "value"],
        [property("sm"), 0, "properties"],
        [text("h-8"), "value"],
      ),
    ),
  ).toBe(true);
  // compoundVariants: [{ size: "sm", class: "p-1" }]
  const compound = (key: string, value: string): Path =>
    down(
      cva,
      [object, 1, "arguments"],
      [property("compoundVariants"), 0, "properties"],
      [{ type: "ArrayExpression" }, "value"],
      [object, 0, "elements"],
      [property(key), 0, "properties"],
      [text(value), "value"],
    );
  expect(isClassName(compound("class", "p-1"))).toBe(true);
  expect(isClassName(compound("size", "sm"))).toBe(false);
});

test("cva's default variants name variants and are mutated", () => {
  expect(
    isClassName(
      down(
        call("cva"),
        [object, 1, "arguments"],
        [property("defaultVariants"), 0, "properties"],
        [object, "value"],
        [property("size"), 0, "properties"],
        [text("default"), "value"],
      ),
    ),
  ).toBe(false);
});

test("a string argument of another function, or a JSX text, is mutated", () => {
  expect(
    isClassName(down(call("t"), [text("login.title"), 0, "arguments"])),
  ).toBe(false);
  expect(
    isClassName(
      down({ type: "JSXElement" }, [{ type: "JSXText" }, 0, "children"]),
    ),
  ).toBe(false);
  expect(
    isClassName(down({ type: "ReturnStatement" }, [text("a"), "argument"])),
  ).toBe(false);
});

test("a cn() reached through a non-wrapper node is mutated", () => {
  // cn(label("a")): "a" belongs to label, not to cn
  expect(
    isClassName(
      down(
        call("cn"),
        [call("label"), 0, "arguments"],
        [text("a"), 0, "arguments"],
      ),
    ),
  ).toBe(false);
  // a member callee such as styles.cn() is not the class helper
  expect(
    isClassName(
      down(
        {
          type: "CallExpression",
          callee: { type: "MemberExpression", property: id("cn") },
        },
        [text("a"), 0, "arguments"],
      ),
    ),
  ).toBe(false);
});

test("the plugin registers the class-names ignorer with Stryker", () => {
  const [plugin] = strykerPlugins;
  expect(plugin?.kind).toBe("Ignore");
  expect(plugin?.name).toBe("class-names");
  const path = down(attribute("className"), [text("a"), "value"]);
  expect(plugin?.value.shouldIgnore(path)).toBe(
    "Class names: styling is checked by screenshots, not unit tests",
  );
  expect(
    plugin?.value.shouldIgnore(down(attribute("title"), [text("a"), "value"])),
  ).toBeUndefined();
});
