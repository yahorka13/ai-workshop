import { expect, test } from "@playwright/test";
import { demoSession, graphql } from "./fixtures/api";
import { signIn } from "./fixtures/auth";
import { dashboardStats } from "./fixtures/dashboard";

/* The dashboard query as a client sees it, against the demo user bin/up
   seeds. */

// The UTC day `offset` days from today, YYYY-MM-DD.
function utcDay(offset: number): string {
  return new Date(Date.now() + offset * 86_400_000).toISOString().slice(0, 10);
}

test("[dashboard-57cd2b] a signed-in client reads the dashboard", async () => {
  const { totalUsers, signUps } = await dashboardStats(await demoSession());
  expect(totalUsers).toBeGreaterThanOrEqual(1);
  expect(signUps.map((entry) => entry.day)).toEqual(
    [-6, -5, -4, -3, -2, -1, 0].map(utcDay),
  );
  expect(signUps.every((entry) => entry.count >= 0)).toBe(true);
  const sum = signUps.reduce((total, entry) => total + entry.count, 0);
  expect(sum).toBeLessThanOrEqual(totalUsers);
});

test("[dashboard-5ee8ff] a signed-out client is refused the dashboard", async () => {
  expect(await graphql("{ dashboard { totalUsers } }")).toMatchObject({
    data: null,
    errors: [{ extensions: { code: "UNAUTHENTICATED" } }],
  });
});

/* The same, as a person in the browser sees it. */

// The short UTC weekday and day the dashboard labels a YYYY-MM-DD day with.
function dayLabel(day: string): string {
  const date = new Date(`${day}T00:00:00Z`);
  const weekday = date.toLocaleDateString("en", {
    weekday: "short",
    timeZone: "UTC",
  });
  return `${weekday} ${String(date.getUTCDate())}`;
}

test("[dashboard-9e4f6d] the dashboard shows the API's stats", async ({
  page,
}) => {
  await signIn(page);
  // The sign-in click leaves the pointer over the chart; move it off, so no
  // tooltip covers the page.
  await page.mouse.move(0, 0);
  const { totalUsers, signUps } = await dashboardStats(await demoSession());
  const main = page.getByRole("main");
  await expect(main.getByRole("heading", { name: "Dashboard" })).toBeVisible();
  const week = signUps.reduce((total, entry) => total + entry.count, 0);
  await expect(main.getByRole("group", { name: "Total users" })).toContainText(
    String(totalUsers),
  );
  await expect(
    main.getByRole("group", { name: "Sign-ups, last 7 days" }),
  ).toContainText(String(week));
  const label = signUps
    .map((entry) => `${dayLabel(entry.day)}: ${String(entry.count)}`)
    .join(", ");
  const chart = main.getByRole("img", { name: `Sign-ups per day: ${label}` });
  await expect(chart).toBeVisible();
  await expect(chart.locator("svg").first()).toBeVisible();
});

test("[dashboard-6a87f4] a failed dashboard load shows the notice", async ({
  page,
}) => {
  await signIn(page);
  // Fail only the dashboard query; the viewer and health queries go through.
  await page.route("**/graphql", async (route) => {
    const body: unknown = route.request().postDataJSON();
    const dashboard =
      typeof body === "object" &&
      body !== null &&
      "operationName" in body &&
      body.operationName === "Dashboard";
    await (dashboard ? route.abort() : route.continue());
  });
  await page.reload();
  const main = page.getByRole("main");
  await expect(
    main.getByRole("heading", { name: "Couldn't load the dashboard." }),
  ).toBeVisible();
  await expect(main.getByText("Reload to try again.")).toBeVisible();
  await expect(main.getByRole("group", { name: "Total users" })).toHaveCount(0);
  await expect(main.getByRole("button", { name: "Reload" })).toBeVisible();
});
