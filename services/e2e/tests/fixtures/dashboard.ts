import { graphql } from "./api";

/* The dashboard's stats as the API answers them, read once and checked, so
   a test compares against real numbers. */

export type Stats = {
  totalUsers: number;
  signUps: { day: string; count: number }[];
};

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}

function signUpDay(entry: unknown): { day: string; count: number } {
  if (
    isRecord(entry) &&
    typeof entry.day === "string" &&
    typeof entry.count === "number"
  ) {
    return { day: entry.day, count: entry.count };
  }
  throw new Error(`not a sign-up day: ${JSON.stringify(entry)}`);
}

/** The stats `dashboard` answers for this session cookie; throws on anything else. */
export async function dashboardStats(cookie: string): Promise<Stats> {
  const answer = await graphql(
    "{ dashboard { totalUsers signUps { day count } } }",
    cookie,
  );
  const data = isRecord(answer) ? answer.data : undefined;
  const dashboard = isRecord(data) ? data.dashboard : undefined;
  if (
    isRecord(dashboard) &&
    typeof dashboard.totalUsers === "number" &&
    Array.isArray(dashboard.signUps)
  ) {
    const entries: unknown[] = dashboard.signUps;
    return {
      totalUsers: dashboard.totalUsers,
      signUps: entries.map(signUpDay),
    };
  }
  throw new Error(`not the dashboard: ${JSON.stringify(answer)}`);
}
