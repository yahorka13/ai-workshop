import { afterEach, expect, spyOn, test } from "bun:test";
import { appServers } from "../support/server";
import { z } from "zod";

const GraphQLErrors = z.object({
  errors: z.array(z.object({ message: z.string() })).min(1),
});

const apps = appServers();

afterEach(apps.close);

function graphql(base: string, body: string): Promise<Response> {
  return fetch(`${base}/graphql`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body,
  });
}

test("[service-checks-7707f9] GET /health answers ok", async () => {
  const base = await apps.start();
  for (const path of ["/health", "/health/"]) {
    const response = await fetch(`${base}${path}`);
    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({ ok: true });
  }
  const head = await fetch(`${base}/health`, { method: "HEAD" });
  expect(head.status).toBe(200);
});

test("[service-checks-b99553] the health query answers over /graphql", async () => {
  const base = await apps.start();
  const response = await graphql(
    base,
    JSON.stringify({ query: "{ health { ok } }" }),
  );
  expect(response.status).toBe(200);
  expect(await response.json()).toEqual({ data: { health: { ok: true } } });
});

test("a GraphQL syntax error or unknown field answers 400 with an error", async () => {
  const base = await apps.start();
  for (const query of ["{ health { ok }", "{ nope }"]) {
    const response = await graphql(base, JSON.stringify({ query }));
    expect(response.status).toBe(400);
    const body: unknown = await response.json();
    const errors = GraphQLErrors.parse(body).errors;
    expect(errors[0]?.message.length).toBeGreaterThan(0);
  }
});

test("a body that is not JSON answers a bare 400, unlogged, and the server keeps serving", async () => {
  const log = spyOn(console, "error").mockImplementation(() => undefined);
  try {
    const base = await apps.start();
    const response = await graphql(base, "{not json");
    expect(response.status).toBe(400);
    expect(await response.json()).toEqual({ error: "Bad request" });
    expect(log).not.toHaveBeenCalled();
    expect((await fetch(`${base}/health`)).status).toBe(200);
  } finally {
    log.mockRestore();
  }
});

test("no answer names the server's framework", async () => {
  const base = await apps.start();
  const response = await fetch(`${base}/health`);
  expect(response.headers.get("x-powered-by")).toBeNull();
});

test("an unknown route answers a JSON 404 without a stack", async () => {
  const base = await apps.start();
  const response = await fetch(`${base}/nope`);
  expect(response.status).toBe(404);
  const text = await response.text();
  expect(JSON.parse(text)).toEqual({ error: "Not found" });
  expect(text).not.toContain("at ");
});
