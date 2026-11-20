import { expect, test } from "@playwright/test";
import { api, demoSession, graphql, origin } from "./fixtures/api";

/* The API's limits on a query's shape, as a client meets them. */

// 101 aliases of health { ok }: 202 fields.
const WIDE = `{ ${Array.from({ length: 101 }, (_, i) => `h${String(i)}: health { ok }`).join(" ")} }`;

// Nine levels, all under the introspection root, which the limits exempt.
const INTROSPECTION =
  "{ __schema { types { fields { type { ofType { ofType { ofType { ofType { name } } } } } } } } }";

test("[contracts-e79819] the API refuses a query selecting too many fields", async ({
  request,
}) => {
  const response = await request.post(`${api}/graphql`, {
    headers: { Origin: origin },
    data: { query: WIDE },
  });
  expect(response.status()).toBe(400);
  expect(await response.json()).toMatchObject({
    errors: [
      {
        message: "Query selects 202 fields; the limit is 100.",
        extensions: { code: "QUERY_TOO_COMPLEX" },
      },
    ],
  });
});

test("[contracts-d1de56] [contracts-4f83fa] the dashboard query passes the limits", async () => {
  const answer = await graphql(
    "{ dashboard { totalUsers signUps { day count } } }",
    await demoSession(),
  );
  expect(answer).toMatchObject({
    data: { dashboard: { totalUsers: expect.any(Number) } },
  });
  expect(answer).not.toHaveProperty("errors");
});

test("[contracts-f0fd4e] a deep introspection query is not refused by the limits", async () => {
  // The stack runs in production mode, which turns introspection off; the
  // limits must still not be what refuses it.
  expect(JSON.stringify(await graphql(INTROSPECTION))).not.toContain(
    "QUERY_TOO_COMPLEX",
  );
});
