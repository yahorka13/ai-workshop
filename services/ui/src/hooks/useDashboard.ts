import { useQuery } from "@apollo/client/react";
import { use } from "react";
import { z } from "zod";
import { DashboardQuery } from "@/services/graphql/dashboard";
import { ApiOriginContext } from "@/services/graphql/origin";

// The API's answer is untrusted: anything but these stats has failed.
const dashboardAnswer = z.object({
  dashboard: z.object({
    totalUsers: z.number().int(),
    signUps: z.array(z.object({ day: z.string(), count: z.number().int() })),
  }),
});

export type Dashboard = z.infer<typeof dashboardAnswer>["dashboard"];

export type DashboardState =
  | { status: "loading"; dashboard?: undefined }
  | { status: "failed" }
  | { status: "ready"; dashboard: Dashboard };

/** The dashboard's stats. A failed request, or no API, has failed. */
export function useDashboard(): DashboardState {
  const configured = use(ApiOriginContext) !== undefined;
  const { data, error } = useQuery(DashboardQuery, { skip: !configured });
  if (!configured || error) return { status: "failed" };
  if (data === undefined) return { status: "loading" };
  const answer = dashboardAnswer.safeParse(data);
  // The parse keeps only the fields above, so Apollo's __typename stays out.
  return answer.success
    ? { status: "ready", dashboard: answer.data.dashboard }
    : { status: "failed" };
}
