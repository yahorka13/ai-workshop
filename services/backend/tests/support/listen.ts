import type { Express } from "express";
import { defined } from "./defined";

/** Serves `app` on an ephemeral port while `use`, given its base URL, runs. */
export async function serving<T>(
  app: Express,
  use: (base: string) => Promise<T>,
): Promise<T> {
  const server = app.listen(0);
  try {
    await new Promise((resolve) => server.once("listening", resolve));
    const address = defined(server.address(), "server address");
    if (typeof address === "string") throw new Error("expected a TCP address");
    return await use(`http://127.0.0.1:${address.port}`);
  } finally {
    server.close();
  }
}
