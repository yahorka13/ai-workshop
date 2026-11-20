import { sanitize, storyNameFromExport, toId } from "storybook/internal/csf";

/** Component modules under src/components/ with no `.stories.tsx` next to them. */
export function componentsWithoutStories(paths: readonly string[]): string[] {
  const all = new Set(paths.map((path) => path.replaceAll("\\", "/")));
  return [...all]
    .filter(
      (path) =>
        path.startsWith("src/components/") &&
        path.endsWith(".tsx") &&
        !path.endsWith(".stories.tsx") &&
        !all.has(path.replace(/\.tsx$/, ".stories.tsx")),
    )
    .sort();
}

const USAGE =
  /description:\s*{\s*component:\s*(?:"(?:[^"\\]|\\.)*\S(?:[^"\\]|\\.)*"|'(?:[^'\\]|\\.)*\S(?:[^'\\]|\\.)*'|`(?:[^`\\]|\\.)*\S(?:[^`\\]|\\.)*`)/;

/** Story files whose meta has no non-empty `parameters.docs.description.component`. */
export function storiesWithoutUsage(
  files: readonly { path: string; source: string }[],
): string[] {
  return files
    .filter(({ source }) => !USAGE.test(source))
    .map(({ path }) => path.replaceAll("\\", "/"))
    .sort();
}

const DARK = /^export const Dark\b/m;

/** Story files with no `Dark` story, the component in the dark theme. */
export function storiesWithoutDark(
  files: readonly { path: string; source: string }[],
): string[] {
  return files
    .filter(({ source }) => !DARK.test(source))
    .map(({ path }) => path.replaceAll("\\", "/"))
    .sort();
}

const META_START = /const meta\b[^=]*=\s*\{/;

/**
 * The text of a story file's meta object at its own level, without nested
 * objects or arrays, so a `title:` inside `args` or a copy object before the
 * meta is not read as the meta's.
 */
function metaTopLevel(source: string): string | undefined {
  const start = META_START.exec(source);
  if (!start) return undefined;
  const scan: MetaScan = { depth: 1, quote: undefined, text: "" };
  for (let i = start.index + start[0].length; i < source.length; i++) {
    const step = scanChar(source, i, scan);
    if (step === "end") return scan.text;
    i += step;
  }
  return scan.text;
}

type MetaScan = { depth: number; quote: string | undefined; text: string };

/** Reads one character inside a string literal; returns how many extra to skip. */
function scanQuoted(source: string, i: number, scan: MetaScan): number {
  const char = source.charAt(i);
  const top = scan.depth === 1;
  if (top) scan.text += char;
  if (char === "\\") {
    if (top) scan.text += source.charAt(i + 1);
    return 1;
  }
  if (char === scan.quote) scan.quote = undefined;
  return 0;
}

/** Opens a string, or moves a level in or out; returns "end" when the meta closes. */
function scanSyntax(char: string, scan: MetaScan): "end" | "close" | "other" {
  if (char === '"' || char === "'" || char === "`") scan.quote = char;
  else if (char === "{" || char === "[") scan.depth++;
  else if (char === "}" || char === "]") {
    scan.depth--;
    return scan.depth === 0 ? "end" : "close";
  }
  return "other";
}

/**
 * Reads one character of the meta, keeping its top-level text; returns how
 * many extra characters to skip, or "end" when the meta closes.
 */
function scanChar(source: string, i: number, scan: MetaScan): number | "end" {
  if (scan.quote !== undefined) return scanQuoted(source, i, scan);
  const char = source.charAt(i);
  const syntax = scanSyntax(char, scan);
  if (syntax === "end") return "end";
  if (syntax === "other" && scan.depth === 1) scan.text += char;
  return 0;
}

const stringProperty = (text: string, key: string): string | undefined =>
  new RegExp(
    `(?:^|[\\s,{])${key}:\\s*(["'\`])((?:(?!\\1)[^\\\\]|\\\\.)*)\\1`,
  ).exec(text)?.[2];

/** A story file's meta title and pinned id, read at the meta's own level. */
function storyMeta(
  source: string,
): { title: string | undefined; id: string | undefined } | undefined {
  const text = metaTopLevel(source);
  if (text === undefined) return undefined;
  return {
    title: stringProperty(text, "title"),
    id: stringProperty(text, "id"),
  };
}

const EXPORT = /^export const (\w+)/gm;
const MDX_META = /<Meta\s[^>]*\btitle="([^"]+)"/;

/**
 * Every Storybook address the files produce: each story's id, each
 * component's autodocs page and each MDX page, sorted.
 */
export function storyIds(
  files: readonly { path: string; source: string }[],
): string[] {
  const ids = new Set<string>();
  for (const file of files) for (const id of fileIds(file)) ids.add(id);
  return [...ids].sort();
}

/** The addresses one story or MDX file produces. */
function fileIds({ path, source }: { path: string; source: string }): string[] {
  if (path.endsWith(".mdx")) {
    const title = MDX_META.exec(source)?.[1];
    return title === undefined ? [] : [`${sanitize(title)}--docs`];
  }
  const meta = storyMeta(source);
  const component = meta?.id ?? meta?.title;
  if (component === undefined) return [];
  return [
    `${sanitize(component)}--docs`,
    ...[...source.matchAll(EXPORT)].map((match) =>
      toId(component, storyNameFromExport(match[1] ?? "")),
    ),
  ];
}

/** Listed addresses that no story produces any more, sorted. */
export function missingStoryIds(
  listed: readonly string[],
  current: readonly string[],
): string[] {
  const have = new Set(current);
  return listed.filter((id) => !have.has(id)).sort();
}
