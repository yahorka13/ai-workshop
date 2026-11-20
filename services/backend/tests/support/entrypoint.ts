// The entry point module, evaluated afresh: the query string makes a new
// instance, since Bun caches a module once evaluated.
import type * as IndexModule from "../../src/index";

const isIndex = (value: unknown): value is typeof IndexModule =>
  typeof value === "object" && value !== null && "server" in value;

export async function freshIndex(): Promise<typeof IndexModule> {
  const loaded: unknown = await import(
    `../../src/index.ts?${crypto.randomUUID()}`
  );
  if (!isIndex(loaded)) throw new Error("src/index.ts has no server");
  return loaded;
}
