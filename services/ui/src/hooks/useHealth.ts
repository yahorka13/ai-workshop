import { useQuery } from "@apollo/client/react";
import { use } from "react";
import { z } from "zod";
import { HealthQuery } from "@/services/graphql/health";
import { ApiOriginContext } from "@/services/graphql/origin";

export type ApiState = "checking" | "online" | "offline" | "unconfigured";

// The API's answer is untrusted: anything else is offline.
const healthAnswer = z.object({ health: z.object({ ok: z.boolean() }) });

/** Whether the API answers, from the backend's health query. */
export function useHealth(): ApiState {
  const configured = use(ApiOriginContext) !== undefined;
  const { data, error } = useQuery(HealthQuery, { skip: !configured });
  if (!configured) return "unconfigured";
  if (error) return "offline";
  if (data === undefined) return "checking";
  const answer = healthAnswer.safeParse(data);
  return answer.success && answer.data.health.ok ? "online" : "offline";
}
