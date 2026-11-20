import { readFileSync } from "node:fs";
import { expect, test } from "bun:test";
import {
  componentsWithoutStories,
  storiesWithoutDark,
  storiesWithoutUsage,
} from "../../tooling/stories";

// Every story file under src/ with its source.
function storyFiles(): { path: string; source: string }[] {
  return [
    ...new Bun.Glob("src/**/*.stories.tsx").scanSync({ onlyFiles: true }),
  ].map((path) => ({ path, source: readFileSync(path, "utf8") }));
}

test("[design-system-e6184f] a component without a story next to it is named", () => {
  expect(
    componentsWithoutStories([
      "src/components/ui/button.tsx",
      "src/components/ui/button.stories.tsx",
      "src/components/ui/card.tsx",
      "src/components/AppHeader.tsx",
      "src/components/AppHeader.stories.tsx",
      "src/components/use-thing.ts",
      "src/components/Example.tsx",
      "src/pages/home/HomePage.tsx",
    ]),
  ).toEqual(["src/components/Example.tsx", "src/components/ui/card.tsx"]);
});

test("[design-system-e6184f] every shared component has a story", () => {
  const paths = [
    ...new Bun.Glob("src/components/**/*.tsx").scanSync({ onlyFiles: true }),
  ];
  expect(paths.length).toBeGreaterThan(0);
  expect(componentsWithoutStories(paths)).toEqual([]);
});

test("[design-system-9bfd31] a story file without a usage note is named", () => {
  const withNote = (component: string): string =>
    `const meta = {\n  parameters: {\n    docs: { description: { component: ${component} } },\n  },\n};\n`;
  expect(
    storiesWithoutUsage([
      { path: "src/b.stories.tsx", source: withNote('"Use it for a row."') },
      { path: "src/z.stories.tsx", source: "const meta = { title: 'Z' };\n" },
      { path: "src/e.stories.tsx", source: withNote('""') },
      { path: "src/w.stories.tsx", source: withNote("'   '") },
      {
        path: "src/t.stories.tsx",
        source: withNote("`\n  Use it for a list.\n`"),
      },
      {
        path: "src/c.stories.tsx",
        source: withNote(
          '\n      "Use it for a card. " +\n      "Don\'t use it for a row."',
        ),
      },
    ]),
  ).toEqual(["src/e.stories.tsx", "src/w.stories.tsx", "src/z.stories.tsx"]);
});

test("[design-system-9bfd31] every story file has a usage note", () => {
  const files = storyFiles();
  expect(files.length).toBeGreaterThan(0);
  expect(storiesWithoutUsage(files)).toEqual([]);
});

test("[design-system-f9f8f3] a story file without a Dark story is named", () => {
  expect(
    storiesWithoutDark([
      { path: "src/a.stories.tsx", source: "export const Dark: Story = {};\n" },
      {
        path: "src/b.stories.tsx",
        source: "export const Primary: Story = {};\n",
      },
      {
        path: "src/c.stories.tsx",
        source: "export const DarkMode: Story = {};\n",
      },
    ]),
  ).toEqual(["src/b.stories.tsx", "src/c.stories.tsx"]);
});

test("[design-system-f9f8f3] every story file has a Dark story", () => {
  const files = storyFiles();
  expect(files.length).toBeGreaterThan(0);
  expect(storiesWithoutDark(files)).toEqual([]);
});
