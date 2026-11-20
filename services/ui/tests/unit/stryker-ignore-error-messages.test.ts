import { expect, test } from "bun:test";
import {
  isErrorText,
  strykerPlugins,
} from "../../tooling/stryker-ignore-error-messages.mjs";

// Minimal Babel paths: each knows its node, its parent path and its key there.
type Path = {
  node: Record<string, unknown> & { type: string };
  parentPath: Path | null;
  key: string | number | null;
  listKey?: string;
};

const root = (node: Path["node"]): Path => ({
  node,
  parentPath: null,
  key: null,
});
const child = (
  parent: Path,
  node: Path["node"],
  key: string | number,
  listKey?: string,
): Path => ({
  node,
  parentPath: parent,
  key,
  ...(listKey === undefined ? {} : { listKey }),
});

const id = (name: string): Path["node"] => ({ type: "Identifier", name });
const text = { type: "StringLiteral", value: "probe failed" };
const template = { type: "TemplateLiteral", quasis: [], expressions: [] };

const argument = (
  callee: Path["node"],
  node: Path["node"],
  index = 0,
  type = "NewExpression",
): Path => child(root({ type, callee }), node, index, "arguments");

// A path inside `class <name> extends <superName> { ... }`.
const inClass = (superName: string | null): Path =>
  root({
    type: "ClassDeclaration",
    id: id("Probe"),
    superClass: superName === null ? null : id(superName),
  });

// The body of `class Probe extends <superName>` and its `name = ...` property.
const nameProperty = (
  superName: string | null,
): { body: Path; property: Path } => {
  const body = child(inClass(superName), { type: "ClassBody" }, "body");
  const property = child(
    body,
    { type: "ClassProperty", key: id("name") },
    0,
    "body",
  );
  return { body, property };
};

test("the message of a constructed Error is skipped", () => {
  expect(isErrorText(argument(id("Error"), text))).toBe(true);
  expect(isErrorText(argument(id("TypeError"), template))).toBe(true);
  expect(isErrorText(argument(id("ConfigError"), text))).toBe(true);
  expect(
    isErrorText(
      argument(
        {
          type: "MemberExpression",
          object: id("errors"),
          property: id("ProbeError"),
        },
        text,
      ),
    ),
  ).toBe(true);
});

test("the name an Error subclass assigns is skipped", () => {
  const { body, property } = nameProperty("Error");
  expect(isErrorText(child(property, text, "value"))).toBe(true);

  const method = child(
    body,
    { type: "ClassMethod", key: id("constructor") },
    0,
    "body",
  );
  const assignment = child(
    method,
    {
      type: "AssignmentExpression",
      left: {
        type: "MemberExpression",
        object: { type: "ThisExpression" },
        property: id("name"),
      },
    },
    "expression",
  );
  expect(isErrorText(child(assignment, text, "right"))).toBe(true);

  const superCall = child(
    method,
    { type: "CallExpression", callee: { type: "Super" } },
    "expression",
  );
  expect(isErrorText(child(superCall, template, 0, "arguments"))).toBe(true);
});

test("client-visible and other strings are still mutated", () => {
  // return "probe reason"
  expect(
    isErrorText(child(root({ type: "ReturnStatement" }), text, "argument")),
  ).toBe(false);
  // new Error("x", { cause }): only the first argument is the message
  expect(
    isErrorText(argument(id("Error"), { type: "ObjectExpression" }, 1)),
  ).toBe(false);
  // ws.close(4001, "reason")
  expect(
    isErrorText(
      argument(
        { type: "MemberExpression", object: id("ws"), property: id("close") },
        text,
        1,
        "CallExpression",
      ),
    ),
  ).toBe(false);
  // new GraphQLError("x"): its message is sent to the client
  expect(isErrorText(argument(id("GraphQLError"), text))).toBe(false);
  expect(
    isErrorText(
      argument(
        {
          type: "MemberExpression",
          object: id("graphql"),
          property: id("GraphQLError"),
        },
        text,
      ),
    ),
  ).toBe(false);
  // fail("x") and new Map("x"): not Error constructors
  expect(isErrorText(argument(id("fail"), text, 0, "CallExpression"))).toBe(
    false,
  );
  expect(isErrorText(argument(id("Map"), text))).toBe(false);
  // a numeric argument of new Error
  expect(isErrorText(argument(id("Error"), { type: "NumericLiteral" }))).toBe(
    false,
  );

  // name and super(...) outside an Error subclass, and a class with no superclass
  for (const superName of ["Base", null]) {
    const { body, property } = nameProperty(superName);
    expect(isErrorText(child(property, text, "value"))).toBe(false);
    const superCall = child(
      body,
      { type: "CallExpression", callee: { type: "Super" } },
      0,
      "body",
    );
    expect(isErrorText(child(superCall, text, 0, "arguments"))).toBe(false);
  }

  // another property of an Error subclass, and this.name outside any class
  const body = child(inClass("Error"), { type: "ClassBody" }, "body");
  const code = child(
    body,
    { type: "ClassProperty", key: id("code") },
    0,
    "body",
  );
  expect(isErrorText(child(code, text, "value"))).toBe(false);
  const loose = child(
    root({ type: "ExpressionStatement" }),
    {
      type: "AssignmentExpression",
      left: {
        type: "MemberExpression",
        object: { type: "ThisExpression" },
        property: id("name"),
      },
    },
    "expression",
  );
  expect(isErrorText(child(loose, text, "right"))).toBe(false);
  expect(isErrorText(root(text))).toBe(false);
});

test("the plugin registers the error-messages ignorer with Stryker", () => {
  const [declared] = strykerPlugins;
  expect(declared?.kind).toBe("Ignore");
  expect(declared?.name).toBe("error-messages");
  expect(declared?.value.shouldIgnore(argument(id("Error"), text))).toBe(
    "Thrown error text: the message is not behaviour",
  );
  expect(declared?.value.shouldIgnore(root(text))).toBeUndefined();
});
