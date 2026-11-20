import { afterEach, expect, test } from "bun:test";
import { appServers } from "../support/server";

const apps = appServers();

afterEach(apps.close);

async function healthQuery(base: string): Promise<unknown> {
  const response = await fetch(`${base}/graphql`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ query: "{ health { ok } }" }),
  });
  return response.json();
}

test("[service-checks-1b899c] an unreachable database fails the health check", async () => {
  for (const probe of [
    () => Promise.resolve(false),
    () => Promise.reject(new Error("connection refused")),
  ]) {
    const base = await apps.start(probe);
    const response = await fetch(`${base}/health`);
    expect(response.status).toBe(503);
    expect(await response.json()).toEqual({ ok: false });
    expect(await healthQuery(base)).toEqual({
      data: { health: { ok: false } },
    });
    apps.close();
  }
});

test("a reachable database is healthy over HTTP and GraphQL", async () => {
  const base = await apps.start(() => Promise.resolve(true));
  const response = await fetch(`${base}/health`);
  expect(response.status).toBe(200);
  expect(await response.json()).toEqual({ ok: true });
  expect(await healthQuery(base)).toEqual({ data: { health: { ok: true } } });
});
