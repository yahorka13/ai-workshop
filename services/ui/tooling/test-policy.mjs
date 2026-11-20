import { expect as bunExpect } from "bun:test";

/** @typedef {import("eslint").Rule.RuleContext} Context */
/** @typedef {Parameters<Context["sourceCode"]["getScope"]>[0]} Node */
/** @typedef {Extract<Node, { type: "CallExpression" }>} Call */
/** @typedef {{ callback: Node | undefined, assertions: number, behavioral: number }} TestEntry */
/** @typedef {{ tests: Map<Node, TestEntry>, matchers: Set<string>, context: Context }} State */

/** @param {Node} node @param {Context} context */
function importedName(node, context) {
  if (node.type !== "Identifier") return undefined;
  /** @type {ReturnType<Context["sourceCode"]["getScope"]> | null} */
  let scope = context.sourceCode.getScope(node);
  while (scope) {
    const variable = scope.set.get(node.name);
    if (variable) {
      const definition = variable.defs[0];
      if (
        definition?.type === "ImportBinding" &&
        definition.node.type === "ImportSpecifier" &&
        definition.parent.source.value === "bun:test"
      ) {
        const imported = definition.node.imported;
        return imported.type === "Identifier" ? imported.name : imported.value;
      }
      return undefined;
    }
    scope = scope.upper;
  }
  return undefined;
}

/** @param {Node} node */
function rootCall(node) {
  while (node.type === "CallExpression" || node.type === "MemberExpression") {
    node = node.type === "CallExpression" ? node.callee : node.object;
  }
  return node;
}

const snapshots = new Set([
  "toMatchSnapshot",
  "toMatchInlineSnapshot",
  "toThrowErrorMatchingSnapshot",
  "toThrowErrorMatchingInlineSnapshot",
]);
const modifiers = new Set(["not", "resolves", "rejects", "constructor"]);
const builtinMatchers = Object.getOwnPropertyNames(
  Object.getPrototypeOf(bunExpect(undefined)),
).filter((name) => !modifiers.has(name));
const builders = new Set(["each", "if", "skipIf", "todoIf"]);

// The rule's options, which ESLint has checked against the schema below.
/** @param {unknown} options @returns {string[]} */
function additionalMatchers(options) {
  if (typeof options !== "object" || options === null) return [];
  if (!("additionalMatchers" in options)) return [];
  const list = options.additionalMatchers;
  if (!Array.isArray(list)) return [];
  return list.filter((name) => typeof name === "string");
}

/** @param {boolean} behavioral @returns {import("eslint").Rule.RuleMetaData} */
function ruleMeta(behavioral) {
  return {
    type: "problem",
    schema: [
      {
        type: "object",
        properties: {
          additionalMatchers: {
            type: "array",
            items: { type: "string" },
            uniqueItems: true,
          },
        },
        additionalProperties: false,
      },
    ],
    messages: {
      missing: behavioral
        ? "Add an explicit non-snapshot behavioral assertion in this test callback."
        : "Use an explicit test callback containing a completed assertion.",
    },
  };
}

// Builders take tables/conditions, registrations take title/callback.
/** @param {Call} node */
function isBuilder(node) {
  return (
    node.callee.type === "MemberExpression" &&
    node.callee.property.type === "Identifier" &&
    builders.has(node.callee.property.name)
  );
}

/** @param {Call} node @param {Set<string>} matchers @returns {string | undefined} */
function matcherName(node, matchers) {
  const callee = node.callee;
  if (
    callee.type !== "MemberExpression" ||
    callee.computed ||
    callee.property.type !== "Identifier" ||
    !matchers.has(callee.property.name)
  )
    return undefined;
  return callee.property.name;
}

/** @param {Call} node @param {Context} context */
function isExpectChain(node, context) {
  /** @type {Node} */
  let assertion = node.callee;
  while (assertion.type === "MemberExpression") assertion = assertion.object;
  return (
    assertion.type === "CallExpression" &&
    importedName(assertion.callee, context) === "expect"
  );
}

/** @param {Node[]} ancestors @param {Map<Node, TestEntry>} tests */
function owningTest(ancestors, tests) {
  return [...tests.values()].findLast(
    (entry) =>
      entry.callback !== undefined && ancestors.includes(entry.callback),
  );
}

/** @param {Node} node */
function isFunction(node) {
  return (
    node.type === "ArrowFunctionExpression" ||
    node.type === "FunctionExpression" ||
    node.type === "FunctionDeclaration"
  );
}

/** @param {Call} node @param {State} state */
function recordAssertion(node, state) {
  const name = matcherName(node, state.matchers);
  if (name === undefined || !isExpectChain(node, state.context)) return;
  const ancestors = state.context.sourceCode.getAncestors(node);
  const owner = owningTest(ancestors, state.tests);
  if (!owner) return;
  if (ancestors.findLast(isFunction) !== owner.callback) return;
  owner.assertions++;
  if (!snapshots.has(name)) owner.behavioral++;
}

/** @param {Map<Node, TestEntry>} tests @param {boolean} behavioral @param {Context} context */
function reportMissing(tests, behavioral, context) {
  for (const [node, result] of tests) {
    if (
      behavioral
        ? result.assertions > 0 && result.behavioral === 0
        : result.assertions === 0
    )
      context.report({ node, messageId: "missing" });
  }
}

/** @param {boolean} behavioral @returns {import("eslint").Rule.RuleModule} */
function makeRule(behavioral) {
  return {
    meta: ruleMeta(behavioral),
    create(context) {
      /** @type {State} */
      const state = {
        tests: new Map(),
        matchers: new Set([
          ...builtinMatchers,
          ...additionalMatchers(context.options[0]),
        ]),
        context,
      };
      return {
        CallExpression(node) {
          const name = importedName(rootCall(node.callee), context);
          if (name !== "test" && name !== "it") recordAssertion(node, state);
          else if (!isBuilder(node))
            state.tests.set(node, {
              callback: node.arguments[1],
              assertions: 0,
              behavioral: 0,
            });
        },
        "Program:exit"() {
          reportMissing(state.tests, behavioral, context);
        },
      };
    },
  };
}

export default {
  rules: {
    "require-assertion": makeRule(false),
    "require-behavioral-assertion": makeRule(true),
  },
};
