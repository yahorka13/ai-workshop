import { expect, spyOn, test } from "bun:test";
import { MockedProvider } from "@apollo/client/testing/react";
import type { MockLink } from "@apollo/client/testing";
import { fireEvent, render, screen, within } from "@testing-library/react";
import { DashboardPage } from "@/pages/dashboard/DashboardPage";
import { ApiOriginContext } from "@/services/graphql/origin";
import {
  dashboardAnswer,
  dashboardOffline,
  stats,
  week,
} from "../../../support/dashboard";
import { withLayout } from "../../../support/layout";

withLayout();

function show(mock: MockLink.MockedResponse): void {
  render(
    <ApiOriginContext value="http://api.test">
      <MockedProvider mocks={[mock]}>
        <DashboardPage />
      </MockedProvider>
    </ApiOriginContext>,
  );
}

// The tile, or the chart's card, named `label`.
function tile(label: string): HTMLElement {
  return screen.getByRole("group", { name: label });
}

test("[dashboard-9e4f6d] the dashboard shows the stats in its tiles and chart", async () => {
  show(dashboardAnswer(stats));
  expect(screen.getByRole("heading", { name: "Dashboard" })).toBeDefined();
  expect(screen.getByText("Who has joined Factory.")).toBeDefined();
  const chart = await screen.findByRole("img", {
    name: "Sign-ups per day: Wed 11: 0, Thu 12: 1, Fri 13: 0, Sat 14: 0, Sun 15: 2, Mon 16: 0, Tue 17: 1",
  });
  expect(chart.querySelector("svg")).not.toBeNull();
  expect(within(tile("Total users")).getByText("12")).toBeDefined();
  expect(within(tile("Sign-ups, last 7 days")).getByText("4")).toBeDefined();
});

test("while loading, the tiles and the chart say so", () => {
  show(dashboardAnswer(stats, 10_000));
  expect(within(tile("Total users")).getByText("Loading…")).toBeDefined();
  expect(
    within(tile("Sign-ups, last 7 days")).getByText("Loading…"),
  ).toBeDefined();
  expect(within(tile("Sign-ups per day")).getByText("Loading…")).toBeDefined();
});

test("a week without sign-ups still shows zero and the chart", async () => {
  const quiet = week.map((entry) => ({ ...entry, count: 0 }));
  show(dashboardAnswer({ ...stats, signUps: quiet }));
  expect(
    await screen.findByRole("img", { name: /^Sign-ups per day: Wed 11: 0,/ }),
  ).toBeDefined();
  expect(within(tile("Sign-ups, last 7 days")).getByText("0")).toBeDefined();
});

test.each([
  ["a failed request", dashboardOffline],
  ["a malformed answer", dashboardAnswer({ __typename: "Dashboard" })],
] as const)(
  "[dashboard-6a87f4] %s shows the notice, and Reload reloads",
  async (_case, mock) => {
    const reload = spyOn(window.location, "reload").mockImplementation(
      () => undefined,
    );
    show(mock);
    expect(
      await screen.findByRole("heading", {
        name: "Couldn't load the dashboard.",
      }),
    ).toBeDefined();
    expect(screen.getByText("Reload to try again.")).toBeDefined();
    expect(screen.queryByText("Total users")).toBeNull();
    fireEvent.click(screen.getByRole("button", { name: "Reload" }));
    expect(reload).toHaveBeenCalledTimes(1);
    reload.mockRestore();
  },
);
