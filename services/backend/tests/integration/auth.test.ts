import { afterEach, beforeEach, expect, test } from "bun:test";
import { appServers, appUrl } from "../support/server";

const apps = appServers();
let base = "";

beforeEach(async () => {
  base = await apps.startSeeded();
});
afterEach(apps.close);

function signIn(
  body: string | Record<string, string>,
  origin = appUrl,
): Promise<Response> {
  return fetch(`${base}/api/auth/sign-in/email`, {
    method: "POST",
    headers: { "content-type": "application/json", origin },
    body: typeof body === "string" ? body : JSON.stringify(body),
  });
}

const demo = { email: "demo@example.com", password: "password" };

test("[auth-11d5f5] the demo user signs in with an HttpOnly session cookie", async () => {
  const response = await signIn(demo);
  expect(response.status).toBe(200);
  expect(response.headers.get("set-cookie")).toContain("HttpOnly");
});

test("an email in another letter case signs in the same user", async () => {
  const response = await signIn({ ...demo, email: "Demo@Example.com" });
  expect(response.status).toBe(200);
});

test("[auth-4d4c2a] [auth-713df6] a wrong password and an unknown email are refused alike", async () => {
  const wrong = await signIn({ ...demo, password: "wrong-password" });
  const unknown = await signIn({ ...demo, email: "nobody@example.com" });
  expect(wrong.status).toBe(401);
  expect(unknown.status).toBe(401);
  expect(wrong.headers.get("set-cookie")).toBeNull();
  expect(unknown.headers.get("set-cookie")).toBeNull();
  expect(await unknown.json()).toEqual(await wrong.json());
});

test("a sign-in body that is not JSON is a client error", async () => {
  const response = await signIn("not json");
  expect(response.status).toBeGreaterThanOrEqual(400);
  expect(response.status).toBeLessThan(500);
});

test("[auth-bb4c24] sign-up is refused", async () => {
  const response = await fetch(`${base}/api/auth/sign-up/email`, {
    method: "POST",
    headers: { "content-type": "application/json", origin: appUrl },
    body: JSON.stringify({
      email: "new@example.com",
      name: "New",
      password: "password123",
    }),
  });
  expect(response.status).toBeGreaterThanOrEqual(400);
  expect(
    (await signIn({ email: "new@example.com", password: "password123" }))
      .status,
  ).toBe(401);
});

test("[auth-e26127] a sign-in from another origin is refused", async () => {
  const response = await signIn(demo, "http://evil.example");
  expect(response.status).toBe(403);
  expect(response.headers.get("set-cookie")).toBeNull();
});

test("[auth-9a6d59] signing out ends the session", async () => {
  const cookie = (await signIn(demo)).headers.get("set-cookie") ?? "";
  const session = cookie.split(";")[0] ?? "";
  const signedOut = await fetch(`${base}/api/auth/sign-out`, {
    method: "POST",
    headers: { origin: appUrl, cookie: session },
  });
  expect(signedOut.status).toBe(200);
  const after = await fetch(`${base}/api/auth/get-session`, {
    headers: { origin: appUrl, cookie: session },
  });
  expect(await after.json()).toBeNull();
});

// Wrong sign-ins from this test's one address; `forwarded` is what each
// attempt claims in X-Forwarded-For, if anything.
async function wrongSignIns(
  app: string,
  count: number,
  forwarded: (attempt: number) => Record<string, string> = () => ({}),
): Promise<number[]> {
  const statuses: number[] = [];
  for (let attempt = 0; attempt < count; attempt += 1) {
    const response = await fetch(`${app}/api/auth/sign-in/email`, {
      method: "POST",
      headers: {
        "content-type": "application/json",
        origin: appUrl,
        ...forwarded(attempt),
      },
      body: JSON.stringify({ ...demo, password: "wrong-password" }),
    });
    statuses.push(response.status);
  }
  return statuses;
}

test("[auth-cd4770] repeated sign-ins are limited off a local stack, whatever address the client claims", async () => {
  const limited = await apps.startSeeded({ rateLimited: true });
  const claimed = (attempt: number): Record<string, string> => ({
    "x-forwarded-for": `203.0.113.${String(attempt + 1)}`,
  });
  expect(await wrongSignIns(limited, 4, claimed)).toEqual([401, 401, 401, 429]);
});

test("[auth-6a165f] a local stack does not limit sign-in", async () => {
  expect(await wrongSignIns(base, 5)).toEqual([401, 401, 401, 401, 401]);
});
