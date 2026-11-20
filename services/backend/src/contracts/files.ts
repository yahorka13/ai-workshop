// Shared by every generated contract: the notice that marks a file as
// generated, and the comparison the read-only check relies on.
import { existsSync, readFileSync, readdirSync } from "node:fs";
import { join, relative, sep } from "node:path";

const generatedNotice = [
  "Generated file: do not edit it by hand.",
  "Change its source and run bin/contracts generate.",
] as const;

// The notice as line comments in the target language, e.g. `#` for GraphQL.
export function commentNotice(prefix: string): string {
  return generatedNotice.map((line) => `${prefix} ${line}\n`).join("");
}

// Relative paths of every file under `root`; an absent root has none.
function files(root: string): string[] {
  if (!existsSync(root)) return [];
  return readdirSync(root, { recursive: true, withFileTypes: true })
    .filter((entry) => entry.isFile())
    .map((entry) =>
      relative(root, join(entry.parentPath, entry.name)).split(sep).join("/"),
    )
    .sort();
}

export type TreeDifference = {
  changed: string[];
  missing: string[];
  extra: string[];
};

// Byte comparison of a freshly generated tree with the committed one. `missing`
// files were generated but are not committed; `extra` ones are committed but
// no longer generated.
export function compareTrees(
  expectedDir: string,
  actualDir: string,
): TreeDifference {
  const expected = files(expectedDir);
  const actual = files(actualDir);
  const present = new Set(actual);
  const wanted = new Set(expected);
  return {
    changed: expected.filter(
      (path) =>
        present.has(path) &&
        !readFileSync(join(expectedDir, path)).equals(
          readFileSync(join(actualDir, path)),
        ),
    ),
    missing: expected.filter((path) => !present.has(path)),
    extra: actual.filter((path) => !wanted.has(path)),
  };
}
