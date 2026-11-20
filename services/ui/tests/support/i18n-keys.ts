/** Every leaf key of a locale object, as dotted paths (`app.name`). */
export function localeKeys(locale: unknown, prefix = ""): string[] {
  if (typeof locale !== "object" || locale === null) return [prefix];
  return Object.entries(locale).flatMap(([key, value]) =>
    localeKeys(value, prefix === "" ? key : `${prefix}.${key}`),
  );
}

/** The keys that no source quotes, as `"key"`, `'key'` or `` `key` ``. */
export function unusedKeys(
  keys: readonly string[],
  sources: readonly string[],
): string[] {
  const text = sources.join("\n");
  return keys.filter(
    (key) =>
      !['"', "'", "`"].some((quote) => text.includes(`${quote}${key}${quote}`)),
  );
}
