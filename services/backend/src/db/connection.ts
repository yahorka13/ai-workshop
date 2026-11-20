// The one place every entry point connects to PostgreSQL: the server and the
// migration runner, both as the owner role from .env.
//
// Where the database listens comes from POSTGRES_URL, which carries no
// credential; who connects comes from POSTGRES_USER and POSTGRES_PASSWORD.
// Errors name a missing variable, never a value: a connection string is a
// credential.
import { drizzle, type NodePgDatabase } from "drizzle-orm/node-postgres";
import type { PgAsyncDatabase, PgQueryResultHKT } from "drizzle-orm/pg-core";
import { Pool } from "pg";
import { z } from "zod";

type Env = Record<string, string | undefined>;

function variable(env: Env, name: string): string {
  const parsed = z.string().min(1).safeParse(env[name]);
  if (!parsed.success) throw new Error(`Set ${name}`);
  return parsed.data;
}

// Host and port, and any connection parameters such as sslmode; never a
// user, a password or a database, which come from their own variables.
const postgresLocation = z
  .string()
  .transform((value) => URL.parse(value))
  .refine(
    (url): url is URL =>
      (url?.protocol === "postgres:" || url?.protocol === "postgresql:") &&
      url.hostname !== "" &&
      url.username === "" &&
      url.password === "" &&
      (url.pathname === "" || url.pathname === "/") &&
      url.hash === "",
  );

function location(env: Env): URL {
  const parsed = postgresLocation.safeParse(variable(env, "POSTGRES_URL"));
  if (!parsed.success)
    throw new Error(
      "POSTGRES_URL must be postgres://<host>[:<port>] with no credentials or path",
    );
  return parsed.data;
}

/** The owner's connection string, every part encoded. */
export function databaseUrl(env: Env): string {
  const where = location(env);
  const user = encodeURIComponent(variable(env, "POSTGRES_USER"));
  const password = encodeURIComponent(variable(env, "POSTGRES_PASSWORD"));
  const database = encodeURIComponent(variable(env, "POSTGRES_DB"));
  return `postgres://${user}:${password}@${where.host}/${database}${where.search}`;
}

/**
 * pg emits `error` on a client the database drops, idle or checked out, and
 * repeats it on the pool for an idle one; unhandled, either ends the process.
 * Each client's own listener logs it once, so the pool's listener only keeps
 * the process alive. The failed query still rejects.
 */
export function createPool(
  connectionString: string,
  log: (line: string) => void,
  options: { max?: number } = {},
): Pool {
  const pool = new Pool({ connectionString, max: options.max ?? 5 });
  pool.on("error", () => {
    // Logged once by the client's own listener below.
  });
  pool.on("connect", (client) => {
    client.on("error", (error) => {
      log(`database connection error: ${error.message}`);
    });
  });
  return pool;
}

export type Database = NodePgDatabase & { $client: Pool };

/** The Drizzle database over a pool. */
export function createDatabase(pool: Pool): Database {
  return drizzle({ client: pool });
}

/** Any PostgreSQL database Drizzle drives: the pool's, or PGlite in tests. */
export type AnyDatabase = PgAsyncDatabase<PgQueryResultHKT>;
