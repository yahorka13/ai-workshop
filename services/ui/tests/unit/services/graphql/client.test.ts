import { afterEach, expect, spyOn, test } from "bun:test";
import { createClient } from "@/services/graphql/client";
import { HealthQuery } from "@/services/graphql/health";

const fetchSpy = spyOn(globalThis, "fetch");
afterEach(() => {
  fetchSpy.mockReset();
});

test("a configured client posts to <origin>/graphql and refreshes what it caches", async () => {
  fetchSpy.mockResolvedValue(
    Response.json({ data: { health: { __typename: "Health", ok: true } } }),
  );
  const client = createClient("http://127.0.0.1:11101");
  expect(client.defaultOptions.watchQuery?.fetchPolicy).toBe(
    "cache-and-network",
  );
  const result = await client.query({ query: HealthQuery });
  expect(result.data?.health.ok).toBe(true);
  expect(fetchSpy.mock.calls[0]?.[0]).toBe("http://127.0.0.1:11101/graphql");
  expect(fetchSpy.mock.calls[0]?.[1]?.credentials).toBe("include");
});

test("[app-shell-c757ea] an unconfigured client fails every operation without a request", async () => {
  const client = createClient(undefined);
  const failed: unknown = await client
    .query({ query: HealthQuery })
    .catch((error: unknown) => error);
  expect(String(failed)).toContain("API origin is not configured");
  expect(fetchSpy).not.toHaveBeenCalled();
});
