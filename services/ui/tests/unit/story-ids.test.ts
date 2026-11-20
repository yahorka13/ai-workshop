import { readFileSync } from "node:fs";
import { expect, test } from "bun:test";
import { missingStoryIds, storyIds } from "../../tooling/stories";

const story = (meta: string, exports: string[]): string =>
  `const TEXT = {\n  title: "Columns",\n};\nconst meta = {\n${meta}\n} satisfies Meta;\nexport default meta;\n` +
  exports.map((name) => `export const ${name}: Story = {};\n`).join("");

test("a story's address comes from its meta title and export name", () => {
  expect(
    storyIds([
      {
        path: "src/a.stories.tsx",
        source: story('  title: "status/Summary card",', [
          "Default",
          "WithArrow",
        ]),
      },
    ]),
  ).toEqual([
    "status-summary-card--default",
    "status-summary-card--docs",
    "status-summary-card--with-arrow",
  ]);
});

test("a pinned meta id wins over the title", () => {
  expect(
    storyIds([
      {
        path: "src/b.stories.tsx",
        source: story('  title: "Actions/Button",\n  id: "ui-button",', [
          "Primary",
        ]),
      },
    ]),
  ).toEqual(["ui-button--docs", "ui-button--primary"]);
});

test("a title outside the meta is not the meta's title", () => {
  expect(
    storyIds([
      {
        path: "src/c.stories.tsx",
        source: story('  title: "data/DataGrid",', ["Sorted"]),
      },
    ]),
  ).toContain("data-datagrid--sorted");
});

test("a quoted brace or an escaped quote does not end the meta early", () => {
  expect(
    storyIds([
      {
        path: "src/e.stories.tsx",
        source:
          'const meta = {\n  args: { label: "a } \\" b" },\n  title: "ui/Odd",\n};\nexport const One = {};\n',
      },
    ]),
  ).toEqual(["ui-odd--docs", "ui-odd--one"]);
});

test("an unclosed meta is read to the end of the file", () => {
  expect(
    storyIds([
      {
        path: "src/f.stories.tsx",
        source: 'const meta = {\n  title: "ui/Cut",',
      },
    ]),
  ).toEqual(["ui-cut--docs"]);
});

test("a story file without a meta has no address", () => {
  expect(
    storyIds([{ path: "src/d.stories.tsx", source: "export const A = 1;\n" }]),
  ).toEqual([]);
});

test("an MDX page's address is its docs id", () => {
  expect(
    storyIds([
      {
        path: ".storybook/docs/x.mdx",
        source: '<Meta title="Foundations/Colour" />\n',
      },
      { path: ".storybook/docs/y.mdx", source: "# No meta\n" },
    ]),
  ).toEqual(["foundations-colour--docs"]);
});

test("[design-system-8420a3] a listed address no story produces is named", () => {
  const retitled = storyIds([
    {
      path: "src/b.stories.tsx",
      source: story('  title: "Actions/Button",', ["Primary"]),
    },
  ]);
  expect(
    missingStoryIds(
      ["ui-button--primary", "actions-button--primary"],
      retitled,
    ),
  ).toEqual(["ui-button--primary"]);
});

test("[design-system-8420a3] every listed story address still exists", () => {
  const files = [
    ...new Bun.Glob("src/**/*.stories.tsx").scanSync({ onlyFiles: true }),
    ...new Bun.Glob(".storybook/docs/**/*.mdx").scanSync({ onlyFiles: true }),
  ].map((path) => ({ path, source: readFileSync(path, "utf8") }));
  const listed = readFileSync("tooling/story-ids.txt", "utf8")
    .split("\n")
    .filter((line) => line !== "" && !line.startsWith("#"));
  expect(listed.length).toBeGreaterThan(0);
  expect(missingStoryIds(listed, storyIds(files))).toEqual([]);
});
