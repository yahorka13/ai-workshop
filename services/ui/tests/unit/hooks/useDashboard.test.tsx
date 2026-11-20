import { expect, spyOn, test } from "bun:test";
import type { MockLink } from "@apollo/client/testing";
import { screen } from "@testing-library/react";
import { useDashboard } from "@/hooks/useDashboard";
import {
  dashboardAnswer,
  dashboardOffline,
  stats,
  week,
} from "../../support/dashboard";
import { showHook } from "../../support/hook-probe";

function show(
  mocks: MockLink.MockedResponse[],
  origin: string | undefined,
): void {
  showHook(useDashboard, mocks, origin);
}

test("the dashboard loads, then is ready with its stats", async () => {
  show([dashboardAnswer(stats)], "http://api.test");
  expect(screen.getByRole("status").textContent).toBe('{"status":"loading"}');
  const ready = {
    status: "ready",
    dashboard: {
      totalUsers: 12,
      signUps: week.map(({ day, count }) => ({ day, count })),
    },
  };
  expect(await screen.findByText(JSON.stringify(ready))).toBeDefined();
});

test.each([
  ["a failed request", dashboardOffline],
  [
    "a count that is not a number",
    dashboardAnswer({
      ...stats,
      signUps: [{ __typename: "SignUpDay", day: "2026-11-17", count: "x" }],
    }),
  ],
  [
    "no totalUsers",
    dashboardAnswer({ __typename: "Dashboard", signUps: week }),
  ],
] as const)("%s has failed", async (_case, mock) => {
  show([mock], "http://api.test");
  expect(await screen.findByText('{"status":"failed"}')).toBeDefined();
});

test("without an API origin the dashboard has failed and nothing is sent", () => {
  const fetchSpy = spyOn(globalThis, "fetch");
  show([], undefined);
  expect(screen.getByRole("status").textContent).toBe('{"status":"failed"}');
  expect(fetchSpy).not.toHaveBeenCalled();
  fetchSpy.mockRestore();
});
