import { expect, type Page } from "@playwright/test";

/** The user every stack bin/up starts is seeded with (bin/seed --help). */
export const DEMO = {
  email: "demo@example.com",
  password: "password",
  name: "Demo User",
} as const;

/** Signs in as the demo user from the login page and waits for the app. */
export async function signIn(page: Page, path = "/login"): Promise<void> {
  await page.goto(path);
  await page.getByLabel("Email").fill(DEMO.email);
  await page.getByLabel("Password").fill(DEMO.password);
  await page.getByRole("button", { name: "Sign in" }).click();
  await expect(page.getByRole("banner")).toContainText(DEMO.name);
}
