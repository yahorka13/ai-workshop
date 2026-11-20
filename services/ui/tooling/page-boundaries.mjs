import { posix } from "node:path";

/** @typedef {import("eslint").Rule.RuleContext} Context */
/** @typedef {import("eslint").Rule.Node} Node */

/** @param {string} path */
function pageOf(path) {
  return /(?:^|\/)src\/pages\/([^/]+)\//.exec(path)?.[1];
}

/** @type {import("eslint").Rule.RuleModule} */
const pageImports = {
  meta: {
    type: "problem",
    messages: {
      crossPage:
        "pages/{{own}} must not import from pages/{{other}}; move shared code to components/, hooks/ or services/.",
    },
    schema: [],
  },
  /** @param {Context} context */
  create(context) {
    const filename = context.filename.replaceAll("\\", "/");
    const own = pageOf(filename);
    if (own === undefined) return {};
    const root = filename.slice(0, filename.lastIndexOf("src/pages/"));
    /** @param {Node & { source?: unknown }} node */
    function check(node) {
      const source = /** @type {{ value?: unknown } | null | undefined} */ (
        node.source
      );
      const specifier = source?.value;
      if (typeof specifier !== "string") return;
      const target = specifier.startsWith("@/")
        ? `${root}src/${specifier.slice(2)}`
        : specifier.startsWith(".")
          ? posix.join(posix.dirname(filename), specifier)
          : "";
      const other = pageOf(`${target}/`);
      if (other !== undefined && other !== own)
        context.report({ node, messageId: "crossPage", data: { own, other } });
    }
    return {
      ImportDeclaration: check,
      ExportNamedDeclaration: check,
      ExportAllDeclaration: check,
      ImportExpression: check,
    };
  },
};

export default { rules: { "page-imports": pageImports } };
