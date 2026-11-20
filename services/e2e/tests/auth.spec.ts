import { expect, test, type APIRequestContext } from "@playwright/test";
import { api, graphql, origin } from "./fixtures/api";
import { DEMO, signIn as signInAt } from "./fixtures/auth";

/* Sign-in, the viewer and sign-out as a client sees them: requests to the
   slot's published API port, from the app's origin, against the demo user
   bin/up seeds. */

const demo = { email: "demo@example.com", password: "password" };

type Answer = { status: number; cookie: string | undefined; body: unknown };

async function signIn(
  request: APIRequestContext,
  data: Record<string, string>,
  from = origin,
): Promise<Answer> {
  const response = await request.post(`${api}/api/auth/sign-in/email`, {
    headers: { Origin: from },
    data,
  });
  return {
    status: response.status(),
    cookie: response.headers()["set-cookie"],
    body: await response.json(),
  };
}

// The session cookie's name=value, as a browser sends it back.
function session(answer: Answer): string {
  return (answer.cookie ?? "").split(";")[0] ?? "";
}

// The viewer from a fresh client that sends only the given cookie.
async function viewer(cookie: string | undefined): Promise<unknown> {
  return graphql("{ viewer { name email } }", cookie);
}

test("[auth-11d5f5] [auth-6d9f8a] the demo user signs in on a fresh stack", async ({
  request,
}) => {
  const answer = await signIn(request, demo);
  expect(answer.status).toBe(200);
  expect(answer.cookie).toContain("HttpOnly");
});

test("[auth-4d4c2a] [auth-713df6] a wrong password and an unknown email are refused alike", async ({
  request,
}) => {
  const wrong = await signIn(request, { ...demo, password: "wrong-password" });
  const unknown = await signIn(request, {
    ...demo,
    email: "nobody@example.com",
  });
  expect(wrong.status).toBe(401);
  expect(unknown.status).toBe(401);
  expect(wrong.cookie).toBeUndefined();
  expect(unknown.body).toEqual(wrong.body);
});

test("[auth-bb4c24] sign-up is refused", async ({ request }) => {
  const email = `new-${Date.now()}@example.com`;
  const response = await request.post(`${api}/api/auth/sign-up/email`, {
    headers: { Origin: origin },
    data: { email, name: "New", password: "password123" },
  });
  expect(response.status()).toBeGreaterThanOrEqual(400);
  expect(
    (await signIn(request, { email, password: "password123" })).status,
  ).toBe(401);
});

test("[auth-e26127] a sign-in from another origin is refused", async ({
  request,
}) => {
  const answer = await signIn(request, demo, "http://evil.example");
  expect(answer.status).toBe(403);
  expect(answer.cookie).toBeUndefined();
});

test("[auth-8e45ce] [auth-6fcece] the viewer is the signed-in user, or no one", async ({
  request,
}) => {
  const cookie = session(await signIn(request, demo));
  expect(await viewer(cookie)).toEqual({
    data: { viewer: { name: "Demo User", email: "demo@example.com" } },
  });
  expect(await viewer(undefined)).toEqual({ data: { viewer: null } });
});

test("[auth-9a6d59] signing out ends the session", async ({ request }) => {
  const cookie = session(await signIn(request, demo));
  const signedOut = await request.post(`${api}/api/auth/sign-out`, {
    headers: { Origin: origin, Cookie: cookie },
  });
  expect(signedOut.status()).toBe(200);
  expect(await viewer(cookie)).toEqual({ data: { viewer: null } });
});

test("[auth-6a165f] a local stack does not limit sign-in", async ({
  request,
}) => {
  const statuses: number[] = [];
  for (let attempt = 0; attempt < 5; attempt += 1) {
    const answer = await signIn(request, { ...demo, password: "wrong" });
    statuses.push(answer.status);
  }
  expect(statuses).toEqual([401, 401, 401, 401, 401]);
});

/* The same, as a person in the browser sees it. */

test("[auth-891d75] a signed-out visit opens the login page", async ({
  page,
}) => {
  await page.goto("/");
  await expect(page.getByRole("heading", { name: "Sign in" })).toBeVisible();
  await expect(page).toHaveURL(/\/login\?next=%2F$/);
  await expect(page.getByRole("banner")).toHaveCount(0);
});

test("[auth-5ad99e] signing in returns to the requested page", async ({
  page,
}) => {
  await page.goto("/no-such-page");
  await expect(page).toHaveURL(/\/login\?next=%2Fno-such-page$/);
  await signInAt(page, page.url());
  await expect(page).toHaveURL(/\/no-such-page$/);
  await expect(
    page.getByRole("heading", { name: "Page not found" }),
  ).toBeVisible();
});

test("[auth-06588a] the demo user signs in from the login page", async ({
  page,
}) => {
  await signInAt(page);
  await expect(
    page.getByRole("main").getByRole("heading", { name: "Dashboard" }),
  ).toBeVisible();
  await expect(page.getByRole("banner")).toContainText(DEMO.name);
});

test("[auth-af5987] a wrong password shows an error", async ({ page }) => {
  await page.goto("/login");
  await page.getByLabel("Email").fill(DEMO.email);
  await page.getByLabel("Password").fill("wrong-password");
  await page.getByRole("button", { name: "Sign in" }).click();
  await expect(page.getByRole("alert")).toHaveText("Wrong email or password.");
  await expect(page).toHaveURL(/\/login$/);
});

test("[auth-49f567] a signed-in user opening the login page goes home", async ({
  page,
}) => {
  await signInAt(page);
  await page.goto("/login");
  await expect(
    page.getByRole("main").getByRole("heading", { name: "Dashboard" }),
  ).toBeVisible();
  await expect(page).toHaveURL(/\/$/);
});

test("[auth-c3a4be] signing out returns to the login page", async ({
  page,
}) => {
  await signInAt(page);
  await page
    .getByRole("banner")
    .getByRole("button", { name: "Sign out" })
    .click();
  await expect(page.getByRole("heading", { name: "Sign in" })).toBeVisible();
  await page.goto("/");
  await expect(page.getByRole("heading", { name: "Sign in" })).toBeVisible();
  await expect(page).toHaveURL(/\/login\?next=%2F$/);
});
