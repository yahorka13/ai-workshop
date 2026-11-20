/** @typedef {import("eslint").Rule.RuleContext} Context */
/** @typedef {import("eslint").Rule.Node} Node */

// A hex colour: # and 3, 4, 6 or 8 hex digits, not followed by another letter or digit.
// "_" may follow: Tailwind writes a space as "_" in arbitrary values (#fff_0%).
const HEX =
  "#(?:[0-9a-fA-F]{8}|[0-9a-fA-F]{6}|[0-9a-fA-F]{3,4})(?![0-9a-zA-Z])";
// A class token (no whitespace or quotes) with a hex colour inside its [...] arbitrary value.
const CLASS = "[^\\s\"'`]*";
const ARBITRARY = new RegExp(
  `${CLASS}\\[[^\\]\\s"'\`]*${HEX}[^\\]\\s"'\`]*\\]${CLASS}`,
  "g",
);

/**
 * The class tokens in `text` that hold a hex colour inside a Tailwind
 * arbitrary value, such as `bg-[#fff]` or `[border:1px_solid_#abc]`.
 * @param {string} text
 * @returns {string[]}
 */
function hexInClasses(text) {
  return [...text.matchAll(ARBITRARY)].map((match) => match[0]);
}

/** @type {import("eslint").Rule.RuleModule} */
const noHexClasses = {
  meta: {
    type: "problem",
    messages: {
      hex: "Hard-coded colour {{value}}: use a colour token from src/styles/theme.css.",
    },
    schema: [],
  },
  /** @param {Context} context */
  create(context) {
    /**
     * @param {Node} node
     * @param {unknown} text
     */
    function check(node, text) {
      if (typeof text !== "string") return;
      for (const value of hexInClasses(text))
        context.report({ node, messageId: "hex", data: { value } });
    }
    return {
      Literal: (node) => check(node, node.value),
      TemplateElement: (node) => check(node, node.value.cooked),
    };
  },
};

export default { rules: { "no-hex-classes": noHexClasses } };
