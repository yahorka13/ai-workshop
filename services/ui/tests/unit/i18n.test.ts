import { expect, test } from "bun:test";
import { i18n } from "@/i18n";

const isI18nModule = (value: unknown): value is { i18n: typeof i18n } =>
  typeof value === "object" && value !== null && "i18n" in value;

test("keys resolve to English text", () => {
  expect(i18n.language).toBe("en");
  expect(i18n.t("app.name")).toBe("Factory");
  expect(i18n.t("notFound.title")).toBe("Page not found");
  expect(i18n.t("error.title")).toBe("Something went wrong");
});

test("the first import is ready to translate, before any render", async () => {
  const fresh: unknown = await import(`@/i18n/index.ts?${crypto.randomUUID()}`);
  if (!isI18nModule(fresh)) throw new Error("@/i18n has no i18n instance");
  expect(fresh.i18n.isInitialized).toBe(true);
  expect(fresh.i18n.t("app.name")).toBe("Factory");
});

test("interpolated values are not escaped: React escapes what it renders", () => {
  const text: string = i18n.t("no.such.key", {
    defaultValue: "{{name}}",
    name: "A & <B>",
  });
  expect(text).toBe("A & <B>");
});
