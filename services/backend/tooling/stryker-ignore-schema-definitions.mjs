// A Stryker ignore-plugin: no mutants in the settings of a GraphQL schema
// definition. Pothos reads a field's name, description, nullability, type,
// arguments and resolving function once per process, when the schema is
// first built, so per-test coverage credits each such mutant to whichever test
// built it first and never runs the tests that check the field. The contracts
// gate pins those settings instead. Code inside a function that runs per
// request stays mutated, and so does any node around one: Stryker skips an
// ignored node's whole subtree (change 10-a51b97, design.md).

/**
 * @typedef {{ type: string } & Record<string, unknown>} Node
 * @typedef {{ node: Node, parentPath: Path | null, key: string | number | null, listKey?: string }} Path
 */

const FUNCTION = new Set([
  "ArrowFunctionExpression",
  "FunctionExpression",
  "ObjectMethod",
]);

// Functions Pothos calls for each request, whose code a test does reach.
const PER_REQUEST = new Set([
  "resolve",
  "subscribe",
  "query",
  "load",
  "isTypeOf",
  "resolveType",
]);

/** @param {unknown} node */
const keyName = (node) => {
  const value = /** @type {Node | null | undefined} */ (node);
  if (value?.type === "Identifier") return String(value.name);
  if (value?.type === "StringLiteral") return String(value.value);
  return "";
};

/** True for a function Pothos calls per request. @param {Path} path */
function perRequest(path) {
  if (path.node.type === "ObjectMethod")
    return PER_REQUEST.has(keyName(path.node.key));
  const parent = path.parentPath?.node;
  return (
    parent?.type === "ObjectProperty" &&
    path.key === "value" &&
    PER_REQUEST.has(keyName(parent.key))
  );
}

/** The identifier a callee chain starts from: `builder` for
    `builder.objectRef(...).implement`. @param {unknown} node */
function rootOf(node) {
  let at = /** @type {Node | undefined} */ (node);
  while (at?.type === "MemberExpression" || at?.type === "CallExpression")
    at = /** @type {Node} */ (
      at.type === "MemberExpression" ? at.object : at.callee
    );
  return at?.type === "Identifier" ? String(at.name) : "";
}

/**
 * True for an AST node.
 * @param {unknown} value
 * @returns {value is Node}
 */
function isNode(value) {
  const at = /** @type {Node | null} */ (value);
  return at !== null && typeof at === "object" && typeof at.type === "string";
}

/**
 * True for a method named in PER_REQUEST, or a function that is the value of
 * a property named in it.
 * @param {Node} at
 * @param {Node | null} parent
 * @param {string} key
 */
function isPerRequestFunction(at, parent, key) {
  if (at.type === "ObjectMethod" && PER_REQUEST.has(keyName(at.key)))
    return true;
  return (
    FUNCTION.has(at.type) &&
    parent?.type === "ObjectProperty" &&
    key === "value" &&
    PER_REQUEST.has(keyName(parent.key))
  );
}

// Node fields that hold no code.
const SKIPPED = new Set(["loc", "leadingComments"]);

/** True for a node whose subtree holds a per-request function. @param {unknown} node */
function holdsPerRequest(node) {
  const seen = /** @type {Node[]} */ ([]);
  /**
   * @param {unknown} value
   * @param {Node | null} parent
   * @param {string} key
   * @returns {boolean}
   */
  const visit = (value, parent, key) => {
    if (Array.isArray(value))
      return value.some((item) => visit(item, parent, key));
    if (!isNode(value) || seen.includes(value)) return false;
    seen.push(value);
    if (isPerRequestFunction(value, parent, key)) return true;
    return Object.entries(value).some(
      ([name, child]) => !SKIPPED.has(name) && visit(child, value, name),
    );
  };
  return visit(node, null, "");
}

/**
 * True for a node inside a call on `builder` that holds no per-request
 * function. Stryker skips an ignored node's whole subtree, so a node around a
 * resolver is never skipped: its own mutants stay, and so does the resolver.
 * @param {Path} path
 */
export function isSchemaSetting(path) {
  if (FUNCTION.has(path.node.type) && perRequest(path)) return false;
  if (holdsPerRequest(path.node)) return false;
  for (let at = /** @type {Path | null} */ (path); at; at = at.parentPath) {
    if (at !== path && FUNCTION.has(at.node.type) && perRequest(at))
      return false;
    if (
      at.node.type === "CallExpression" &&
      rootOf(at.node.callee) === "builder"
    )
      return true;
  }
  return false;
}

export const strykerPlugins = [
  {
    kind: "Ignore",
    name: "schema-definitions",
    value: {
      /** @param {Path} path */
      shouldIgnore: (path) =>
        isSchemaSetting(path)
          ? "Schema setting: Pothos reads it once per process; the contracts gate pins it"
          : undefined,
    },
  },
];
