import { expect, test } from "@playwright/test";
import { api, origin } from "./fixtures/api";

/* The backend as a client sees it: requests to the slot's published API port,
   with the app's origin, as the browser sends them. */

test("[service-checks-7707f9] GET /health answers ok", async ({ request }) => {
  const response = await request.get(`${api}/health`);
  expect(response.status()).toBe(200);
  expect(await response.json()).toEqual({ ok: true });
});

test("[service-checks-b99553] the health query answers ok", async ({
  request,
}) => {
  const response = await request.post(`${api}/graphql`, {
    headers: { Origin: origin },
    data: { query: "{ health { ok } }" },
  });
  expect(response.status()).toBe(200);
  expect(await response.json()).toEqual({ data: { health: { ok: true } } });
});
