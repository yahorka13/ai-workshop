import type { MockLink } from "@apollo/client/testing";
import { DashboardQuery } from "@/services/graphql/dashboard";

/** A week of sign-ups, Wed 11 to Tue 17 November 2026, 4 in all. */
export const week = [0, 1, 0, 0, 2, 0, 1].map((count, index) => ({
  __typename: "SignUpDay",
  day: `2026-11-${String(11 + index)}`,
  count,
}));

/** The dashboard query answered with this `dashboard` value, as often as asked. */
export function dashboardAnswer(
  dashboard: unknown,
  delay = 20,
): MockLink.MockedResponse {
  return {
    request: { query: DashboardQuery },
    result: { data: { dashboard } },
    delay,
    maxUsageCount: Number.POSITIVE_INFINITY,
  };
}

/** The dashboard query failing as a network error would. */
export const dashboardOffline: MockLink.MockedResponse = {
  request: { query: DashboardQuery },
  error: new Error("offline"),
};

/** A dashboard of 12 users and `week`. */
export const stats = { __typename: "Dashboard", totalUsers: 12, signUps: week };
