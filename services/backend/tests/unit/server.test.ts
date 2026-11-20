import { expect, test } from "bun:test";
import { drizzle } from "drizzle-orm/node-postgres";
import type { Config } from "../../src/config";
import { authOptions } from "../../src/server";

const config: Config = {
  port: 4000,
  databaseUrl: "postgres://app:secret@postgres:5432/app",
  appUrl: "http://ui.test",
  apiUrl: "http://api.test",
  authSecret: "s".repeat(32),
  localStack: false,
};

// Only passed through, never queried.
const db = drizzle.mock();

test("auth is configured from the configuration, rate limited off a local stack", () => {
  expect(authOptions(config, db)).toEqual({
    db,
    appUrl: "http://ui.test",
    apiUrl: "http://api.test",
    secret: "s".repeat(32),
    rateLimited: true,
  });
  expect(authOptions({ ...config, localStack: true }, db).rateLimited).toBe(
    false,
  );
});
