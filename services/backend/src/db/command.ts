// What the database commands share: --help, one pooled connection to the
// configured database, and a failure printed as its message with exit code 1.
import type { Pool } from "pg";
import { createPool, databaseUrl } from "./connection";

type Io = { log: (line: string) => void; error: (line: string) => void };

/** Runs `work` on a one-connection pool, or prints `usage`; returns the exit code. */
export async function runCommand(
  usage: string,
  work: (pool: Pool) => Promise<void>,
  {
    argv = process.argv,
    env = process.env,
    io = console,
  }: {
    argv?: readonly string[];
    env?: Record<string, string | undefined>;
    io?: Io;
  } = {},
): Promise<number> {
  if (argv.includes("--help")) {
    io.log(usage);
    return 0;
  }
  let pool: Pool | undefined;
  try {
    pool = createPool(databaseUrl(env), io.error, { max: 1 });
    await work(pool);
    return 0;
  } catch (error) {
    io.error(error instanceof Error ? error.message : String(error));
    return 1;
  } finally {
    await pool?.end();
  }
}
