// A Stryker ignore-plugin: no string mutants in the texts of thrown errors.
// An Error's message and an Error subclass's name are read by people, not by
// code, so a mutant there only measures whether a test pins a sentence. Texts
// a client receives are not built here and stay mutated (change 10-a51b97, design.md).

/**
 * @typedef {{ type: string } & Record<string, unknown>} Node
 * @typedef {{ node: Node, parentPath: Path | null, key: string | number | null, listKey?: string }} Path
 */

const TEXT = new Set(["StringLiteral", "TemplateLiteral"]);
const CLASS = new Set(["ClassDeclaration", "ClassExpression"]);

/** @param {unknown} node */
const named = (node) => {
  const value = /** @type {Node | null | undefined} */ (node);
  if (value?.type === "Identifier") return String(value.name);
  if (value?.type === "MemberExpression") return named(value.property);
  return "";
};

// Errors whose message is sent to the client: their texts stay mutated.
const CLIENT_VISIBLE = new Set(["GraphQLError"]);

/** @param {unknown} node */
const isErrorName = (node) => {
  const name = named(node);
  return name.endsWith("Error") && !CLIENT_VISIBLE.has(name);
};

/** @param {Path} path */
function inErrorSubclass(path) {
  for (let at = path.parentPath; at; at = at.parentPath) {
    if (CLASS.has(at.node.type)) return isErrorName(at.node.superClass);
  }
  return false;
}

/**
 * The first argument of `new <X>Error(...)`, or of `super(...)` in an Error
 * subclass.
 * @param {Path} path
 * @param {Node} parent
 */
function isMessageArgument(path, parent) {
  if (path.listKey !== "arguments" || path.key !== 0) return false;
  if (parent.type === "NewExpression") return isErrorName(parent.callee);
  const callee = /** @type {Node} */ (parent.callee);
  return (
    parent.type === "CallExpression" &&
    callee.type === "Super" &&
    inErrorSubclass(path)
  );
}

/**
 * The value of a `name = "..."` class property in an Error subclass.
 * @param {Path} path
 * @param {Node} parent
 */
function isNameProperty(path, parent) {
  return (
    parent.type === "ClassProperty" &&
    path.key === "value" &&
    named(parent.key) === "name" &&
    inErrorSubclass(path)
  );
}

/**
 * The value of `this.name = ...` in an Error subclass.
 * @param {Path} path
 * @param {Node} parent
 */
function isNameAssignment(path, parent) {
  if (parent.type !== "AssignmentExpression" || path.key !== "right")
    return false;
  const left = /** @type {Node} */ (parent.left);
  const object = /** @type {Node | undefined} */ (left.object);
  return (
    object?.type === "ThisExpression" &&
    named(left.property) === "name" &&
    inErrorSubclass(path)
  );
}

const ERROR_TEXTS = [isMessageArgument, isNameProperty, isNameAssignment];

/**
 * True for a string or template literal that is the message of `new
 * <X>Error(...)` or of `super(...)` in an Error subclass, or the `name` an
 * Error subclass assigns.
 * @param {Path} path
 */
export function isErrorText(path) {
  const parent = path.parentPath;
  if (!TEXT.has(path.node.type) || !parent) return false;
  return ERROR_TEXTS.some((matches) => matches(path, parent.node));
}

export const strykerPlugins = [
  {
    kind: "Ignore",
    name: "error-messages",
    value: {
      /** @param {Path} path */
      shouldIgnore: (path) =>
        isErrorText(path)
          ? "Thrown error text: the message is not behaviour"
          : undefined,
    },
  },
];
