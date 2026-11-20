// The health probe over the database pool.
import type { Probe } from "../health";

/** A probe that runs `select 1`; any failure answers false. */
export function databaseProbe(pool: {
  query: (sql: string) => Promise<unknown>;
}): Probe {
  return async () => {
    try {
      await pool.query("select 1");
      return true;
    } catch {
      return false;
    }
  };
}
