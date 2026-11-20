import type { Server } from "node:http";
import { createApp } from "../../src/app";
import { createAuth } from "../../src/auth";
import type { Probe } from "../../src/health";
import { databaseUserStats } from "../../src/db/user-stats";
import { seedDemoUsers } from "../../src/seed";
import { migratedDatabase, type TestDatabase } from "./database";
import { defined } from "./defined";

// The UI origin every test app allows.
export const appUrl = "http://127.0.0.1:11100";

export type AppServers = {
  // Starts the app on an ephemeral port, over a fresh migrated database, and
  // returns its base URL.
  start: (probe?: Probe) => Promise<string>;
  // The same, with the demo user seeded; sign-in is not rate limited unless
  // asked, as on a local stack.
  startSeeded: (options?: { rateLimited?: boolean }) => Promise<string>;
  // The same, over a database that is already closed, so every session
  // lookup fails.
  startOnClosedDatabase: () => Promise<string>;
  // Closes every app started since the last close; pass it to afterEach.
  close: () => void;
};

async function listen(
  open: Server[],
  db: TestDatabase,
  probe: Probe,
  rateLimited = false,
): Promise<string> {
  const app = await createApp({
    probe,
    appUrl,
    userStats: databaseUserStats(db),
    auth: createAuth({
      db,
      appUrl,
      apiUrl: "http://127.0.0.1:4000",
      secret: "s".repeat(32),
      rateLimited,
    }),
  });
  const listening = await new Promise<Server>((resolve) => {
    const started = app.listen(0, () => {
      resolve(started);
    });
  });
  open.push(listening);
  const address = defined(listening.address(), "server address");
  if (typeof address === "string") throw new Error("expected a TCP address");
  return `http://127.0.0.1:${address.port}`;
}

export function appServers(): AppServers {
  const open: Server[] = [];
  return {
    start: async (probe = () => Promise.resolve(true)) =>
      listen(open, await migratedDatabase(), probe),
    startSeeded: async ({ rateLimited = false } = {}) => {
      const db = await migratedDatabase();
      await seedDemoUsers(db, { FACTORY_LOCAL_STACK: "1" });
      return listen(open, db, () => Promise.resolve(true), rateLimited);
    },
    startOnClosedDatabase: async () => {
      const db = await migratedDatabase();
      await db.$client.close();
      return listen(open, db, () => Promise.resolve(true));
    },
    close: () => {
      for (const server of open.splice(0)) server.close();
    },
  };
}

/** Posts a GraphQL query to the app at `base` from the UI's origin. */
export async function graphql(
  base: string,
  query: string,
  cookie?: string,
): Promise<unknown> {
  const response = await fetch(`${base}/graphql`, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      origin: appUrl,
      ...(cookie === undefined ? {} : { cookie }),
    },
    body: JSON.stringify({ query }),
  });
  return response.json();
}

/** Signs the demo user in on a seeded app and returns the session cookie. */
export async function signedInCookie(base: string): Promise<string> {
  const signedIn = await fetch(`${base}/api/auth/sign-in/email`, {
    method: "POST",
    headers: { "content-type": "application/json", origin: appUrl },
    body: JSON.stringify({ email: "demo@example.com", password: "password" }),
  });
  return (signedIn.headers.get("set-cookie") ?? "").split(";")[0] ?? "";
}
