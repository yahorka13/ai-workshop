// The dashboard's stats: how many users there are, and how many signed up on
// each of the last 7 days. It is the domain module the `dashboard` resolver
// reaches data through; the reads it needs are the UserStats port, which
// src/db/user-stats.ts implements over the users table.
export type SignUpDay = {
  /** The UTC calendar day, YYYY-MM-DD. */
  day: string;
  count: number;
};

export type Dashboard = { totalUsers: number; signUps: SignUpDay[] };

/** The reads the dashboard needs; src/db/user-stats.ts implements them. */
export type UserStats = {
  total: () => Promise<number>;
  /** Users created at or after `since`, per UTC day that has any. */
  createdPerDay: (since: Date) => Promise<SignUpDay[]>;
};

const DAYS = 7;
const DAY_MS = 24 * 60 * 60 * 1000;

/** The stats, with sign-ups for the 7 UTC days ending on `now`'s day, oldest first. */
export async function dashboard(
  stats: UserStats,
  now = new Date(),
): Promise<Dashboard> {
  const today = Date.UTC(
    now.getUTCFullYear(),
    now.getUTCMonth(),
    now.getUTCDate(),
  );
  const since = new Date(today - (DAYS - 1) * DAY_MS);
  const [totalUsers, rows] = await Promise.all([
    stats.total(),
    stats.createdPerDay(since),
  ]);
  const counts = new Map(rows.map((row) => [row.day, row.count]));
  const signUps = Array.from({ length: DAYS }, (_, index) => {
    const day = new Date(since.getTime() + index * DAY_MS)
      .toISOString()
      .slice(0, 10);
    return { day, count: counts.get(day) ?? 0 };
  });
  return { totalUsers, signUps };
}
