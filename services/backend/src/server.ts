// Starting the backend: read the configuration, then listen.
import type { Server } from "node:http";
import { createApp } from "./app";
import { createAuth, type AuthOptions } from "./auth";
import { ConfigError, parseConfig, type Config } from "./config";
import { createDatabase, createPool, type AnyDatabase } from "./db/connection";
import { databaseProbe } from "./db/probe";
import { databaseUserStats } from "./db/user-stats";

/** The auth options a configuration gives: sign-in is limited off a local stack. */
export function authOptions(config: Config, db: AnyDatabase): AuthOptions {
  return {
    db,
    appUrl: config.appUrl,
    apiUrl: config.apiUrl,
    secret: config.authSecret,
    rateLimited: !config.localStack,
  };
}

/** Listens on the configured port once the app is ready; rejects on bad configuration. */
export async function start(
  env: Record<string, string | undefined>,
): Promise<Server> {
  const config = parseConfig(env);
  const pool = createPool(config.databaseUrl, console.error);
  const db = createDatabase(pool);
  const app = await createApp({
    probe: databaseProbe(pool),
    appUrl: config.appUrl,
    auth: createAuth(authOptions(config, db)),
    userStats: databaseUserStats(db),
  });
  return new Promise((resolve) => {
    const server = app.listen(config.port, () => {
      console.log(`backend listening on ${config.port}`);
      resolve(server);
    });
  });
}

/** Ends the process on a startup failure: a bad configuration exits 1 naming it. */
export function failStartup(
  error: unknown,
  exit: (code: number) => never = process.exit.bind(process),
): never {
  if (!(error instanceof ConfigError)) throw error;
  console.error(error.message);
  return exit(1);
}
