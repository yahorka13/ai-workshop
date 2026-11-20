import { MockedProvider } from "@apollo/client/testing/react";
import type { MockLink } from "@apollo/client/testing";
import { render } from "@testing-library/react";
import {
  createMemoryRouter,
  RouterProvider,
  type RouteObject,
} from "react-router";
import { HealthQuery } from "@/services/graphql/health";
import { ApiOriginContext } from "@/services/graphql/origin";
import { ViewerQuery } from "@/services/graphql/viewer";
import { dashboardAnswer, stats } from "./dashboard";

export const demo = {
  __typename: "Viewer",
  id: "u1",
  name: "Demo User",
  email: "demo@example.com",
} as const;

// Every query answered as often as asked: the viewer given, a healthy API
// and the dashboard's stats.
function mocks(viewer: typeof demo | null): MockLink.MockedResponse[] {
  return [
    {
      request: { query: ViewerQuery },
      result: { data: { viewer } },
      maxUsageCount: Number.POSITIVE_INFINITY,
    },
    {
      request: { query: HealthQuery },
      result: { data: { health: { __typename: "Health", ok: true } } },
      maxUsageCount: Number.POSITIVE_INFINITY,
    },
    dashboardAnswer(stats, 0),
  ];
}

/** Renders `routes` at `path` for this viewer (null: signed out). */
export function visitAs(
  viewer: typeof demo | null,
  path: string,
  routes: RouteObject[],
): ReturnType<typeof createMemoryRouter> {
  const router = createMemoryRouter(routes, { initialEntries: [path] });
  render(
    <ApiOriginContext value="http://api.test">
      <MockedProvider mocks={mocks(viewer)}>
        <RouterProvider router={router} />
      </MockedProvider>
    </ApiOriginContext>,
  );
  return router;
}
