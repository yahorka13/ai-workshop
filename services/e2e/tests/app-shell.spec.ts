import { expect, test } from "@playwright/test";
import { signIn } from "./fixtures/auth";

test("[app-shell-af1ebe] the home screen shows the layout", async ({
  page,
}) => {
  await signIn(page);
  await page.goto("/");
  const header = page.getByRole("banner");
  await expect(header.getByRole("link", { name: "Factory" })).toBeVisible();
  const dashboard = page
    .getByRole("navigation", { name: "Main" })
    .getByRole("link", { name: "Dashboard" });
  await expect(dashboard).toHaveAttribute("aria-current", "page");
  await expect(
    page.getByRole("main").getByRole("heading", { name: "Dashboard" }),
  ).toBeVisible();
});

test("[app-shell-c88136] an unknown path shows not found", async ({ page }) => {
  await signIn(page);
  await page.goto("/no-such-page");
  await expect(page.getByRole("banner")).toBeVisible();
  await expect(
    page.getByRole("heading", { name: "Page not found" }),
  ).toBeVisible();
  await expect(page.getByRole("link", { name: "Go to home" })).toHaveAttribute(
    "href",
    "/",
  );
});

test("[app-shell-3b054c] the header shows checking, then API online", async ({
  page,
}) => {
  // Hold the first health request until the checking state is seen, then let
  // it through to the real API; the viewer query goes straight through.
  await signIn(page);
  let release = (): void => undefined;
  const held = new Promise<void>((resolve) => {
    release = resolve;
  });
  await page.route("**/graphql", async (route) => {
    const body: unknown = route.request().postDataJSON();
    const health =
      typeof body === "object" &&
      body !== null &&
      "operationName" in body &&
      body.operationName === "Health";
    if (health) await held;
    await route.continue();
  });
  await page.goto("/");
  const status = page.getByRole("banner").getByRole("status");
  await expect(status).toHaveText("Checking API");
  release();
  await expect(status).toHaveText("API online");
});
