// A Stryker ignore-plugin: no string mutants in Tailwind class names. A class
// is styling, which screenshots check, not unit tests, so a mutant there only
// measures whether a test pins a class list. Skipped: the text of a
// `className` attribute, the string arguments of `cn(...)` and `cva(...)`,
// and the classes of a `cva` variant. The condition that picks a class is
// not a string and stays mutated (change 10-a51b97, design.md).

/**
 * @typedef {{ type: string } & Record<string, unknown>} Node
 * @typedef {{ node: Node, parentPath: Path | null, key: string | number | null, listKey?: string }} Path
 */

const TEXT = new Set(["StringLiteral", "TemplateLiteral"]);

// Nodes a class string passes through on its way to a class list: `a && "b"`,
// `a ? "b" : "c"`, `["a", "b"]`, `{ "a": cond }` values and nested objects.
const WRAPPERS = new Set([
  "LogicalExpression",
  "ConditionalExpression",
  "ArrayExpression",
  "ObjectExpression",
  "ObjectProperty",
]);

// Functions whose string arguments are class names.
const CLASS_FUNCTIONS = new Set(["cn", "cva"]);

/** @param {unknown} node */
const named = (node) => {
  const value = /** @type {Node | null | undefined} */ (node);
  if (value?.type === "Identifier" || value?.type === "JSXIdentifier")
    return String(value.name);
  if (value?.type === "StringLiteral") return String(value.value);
  return "";
};

/**
 * True when a wrapper holds the string as a class, not as a condition or
 * a key: a ConditionalExpression's test, a LogicalExpression's left side and
 * an ObjectProperty's key pick classes, they are not classes.
 * @param {Path} at
 */
function holdsAsClass(at) {
  const parent = at.parentPath?.node;
  if (parent?.type === "ConditionalExpression") return at.key !== "test";
  if (parent?.type === "LogicalExpression") return at.key === "right";
  if (parent?.type === "ObjectProperty") return at.key === "value";
  return true;
}

/**
 * True inside a cva call's second argument only for a variant's classes:
 * below `variants`, or the `class` or `className` of a compound variant.
 * `defaultVariants` and a compound variant's selectors name variants, not
 * classes, and stay mutated.
 * @param {Path} path the string
 * @param {Path} call the cva call
 */
function isVariantClass(path, call) {
  for (let at = path.parentPath; at && at !== call; at = at.parentPath) {
    if (at.node.type !== "ObjectProperty") continue;
    const key = named(at.node.key);
    if (key === "variants" || key === "class" || key === "className")
      return true;
  }
  return false;
}

/**
 * The outermost wrapper that holds `path` as a class, the node just below an
 * attribute or a call, or undefined when a wrapper holds it as a condition
 * or a key.
 * @param {Path} path
 * @returns {Path | undefined}
 */
function topOfClassValue(path) {
  let at = path;
  while (at.parentPath && WRAPPERS.has(at.parentPath.node.type)) {
    if (!holdsAsClass(at)) return undefined;
    at = at.parentPath;
  }
  return holdsAsClass(at) ? at : undefined;
}

/** @param {Path} top @param {Path} path */
function isClassArgument(top, path) {
  const call = top.parentPath;
  if (call?.node.type !== "CallExpression" || top.listKey !== "arguments")
    return false;
  const callee = named(call.node.callee);
  if (!CLASS_FUNCTIONS.has(callee)) return false;
  return callee === "cn" || top.key === 0 || isVariantClass(path, call);
}

/** @param {Path} top */
function isClassNameAttribute(top) {
  let at = top.parentPath;
  if (at?.node.type === "JSXExpressionContainer") at = at.parentPath;
  return (
    at?.node.type === "JSXAttribute" && named(at.node.name) === "className"
  );
}

/**
 * True for a string or template literal that is a class list: a `className`
 * attribute's text, a `cn(...)` or `cva(...)` argument, or a cva variant's
 * classes, through `&&`, `?:`, arrays and objects.
 * @param {Path} path
 */
export function isClassName(path) {
  if (!TEXT.has(path.node.type)) return false;
  const top = topOfClassValue(path);
  if (!top) return false;
  return isClassNameAttribute(top) || isClassArgument(top, path);
}

export const strykerPlugins = [
  {
    kind: "Ignore",
    name: "class-names",
    value: {
      /** @param {Path} path */
      shouldIgnore: (path) =>
        isClassName(path)
          ? "Class names: styling is checked by screenshots, not unit tests"
          : undefined,
    },
  },
];
