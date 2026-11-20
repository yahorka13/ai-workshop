// Adds the current Storybook addresses to tooling/story-ids.txt, keeping every
// listed one: the list only grows. Run it after adding stories: bun run story-ids
import { readFileSync, writeFileSync } from "node:fs";
import { storyIds } from "./stories";

const LIST = "tooling/story-ids.txt";
const HEADER =
  "# Every Storybook address. Only grows: bun run story-ids adds new ones; delete a line only when its story is removed on purpose.";

const files = [
  ...new Bun.Glob("src/**/*.stories.tsx").scanSync({ onlyFiles: true }),
  ...new Bun.Glob(".storybook/docs/**/*.mdx").scanSync({ onlyFiles: true }),
].map((path) => ({ path, source: readFileSync(path, "utf8") }));

let listed: string[] = [];
try {
  listed = readFileSync(LIST, "utf8")
    .split("\n")
    .filter((line) => line !== "" && !line.startsWith("#"));
} catch {
  // No list yet: the first run creates it.
}
const all = [...new Set([...listed, ...storyIds(files)])].sort();
writeFileSync(LIST, `${HEADER}\n${all.join("\n")}\n`);
console.log(`${LIST}: ${all.length} addresses`);
