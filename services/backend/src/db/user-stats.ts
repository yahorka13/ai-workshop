// The dashboard's reads over the users table. Days are UTC calendar days, so
// every viewer sees the same counts whatever its time zone.
import { count, gte, sql } from "drizzle-orm";
import { z } from "zod";
import type { UserStats } from "../dashboard";
import type { AnyDatabase } from "./connection";
import { users } from "./schema";

// Postgres counts are bigint, which the driver may answer as a string.
const total = z.tuple([z.object({ count: z.coerce.number().int() })]);
const perDay = z.array(
  z.object({ day: z.string(), count: z.coerce.number().int() }),
);

/** UserStats over the database's users table. */
export function databaseUserStats(db: AnyDatabase): UserStats {
  const day = sql<string>`to_char(${users.createdAt} at time zone 'UTC', 'YYYY-MM-DD')`;
  return {
    total: async () => {
      const rows = await db.select({ count: count() }).from(users);
      const [{ count: all }] = total.parse(rows);
      return all;
    },
    createdPerDay: async (since) =>
      perDay.parse(
        await db
          .select({ day, count: count() })
          .from(users)
          .where(gte(users.createdAt, since))
          .groupBy(day),
      ),
  };
}
