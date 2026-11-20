import { afterEach, beforeEach, expect, test } from "bun:test";
import { appServers, appUrl, graphql, signedInCookie } from "../support/server";

const apps = appServers();
let base = "";

beforeEach(async () => {
  base = await apps.startSeeded();
});
afterEach(apps.close);

async function viewer(cookie?: string): Promise<unknown> {
  return graphql(base, "{ viewer { id name email } }", cookie);
}

test("[auth-8e45ce] a signed-in request sees its user", async () => {
  const cookie = await signedInCookie(base);
  const answer = await viewer(cookie);
  expect(answer).toMatchObject({
    data: { viewer: { name: "Demo User", email: "demo@example.com" } },
  });
  expect(answer).toHaveProperty(["data", "viewer", "id"]);
});

test.each([undefined, "better-auth.session_token=forged"])(
  "[auth-6fcece] a request without a valid session sees no viewer: %p",
  async (cookie) => {
    expect(await viewer(cookie)).toEqual({ data: { viewer: null } });
  },
);

test("a session lookup that fails leaves the request without a viewer", async () => {
  // A real, signed session cookie (every test app shares one secret), so the
  // lookup reaches the closed database.
  const cookie = await signedInCookie(base);
  const broken = await apps.startOnClosedDatabase();
  const response = await fetch(`${broken}/graphql`, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      origin: appUrl,
      cookie,
    },
    body: JSON.stringify({ query: "{ health { ok } viewer { id } }" }),
  });
  expect(response.status).toBe(200);
  expect(await response.json()).toEqual({
    data: { health: { ok: true }, viewer: null },
  });
});
