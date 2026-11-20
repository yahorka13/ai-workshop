import { afterEach, expect, test } from "bun:test";
import { appServers, appUrl } from "../support/server";

const apps = appServers();

afterEach(apps.close);

const query = (base: string, origin: string): Promise<Response> =>
  fetch(`${base}/graphql`, {
    method: "POST",
    headers: { "content-type": "application/json", origin },
    body: JSON.stringify({ query: "{ health { ok } }" }),
  });

test("[service-checks-2900a9] the UI's origin is allowed, with credentials", async () => {
  const response = await query(await apps.start(), appUrl);
  expect(response.status).toBe(200);
  expect(response.headers.get("access-control-allow-origin")).toBe(appUrl);
  expect(response.headers.get("access-control-allow-credentials")).toBe("true");
  expect(response.headers.get("vary")).toContain("Origin");
});

test("[service-checks-3e0690] another origin gets no CORS header", async () => {
  const base = await apps.start();
  for (const origin of [
    "http://elsewhere.test",
    `${appUrl}/`,
    "http://127.0.0.1:11199",
  ]) {
    const response = await query(base, origin);
    expect(response.headers.get("access-control-allow-origin")).toBeNull();
    expect(response.headers.get("vary")).toContain("Origin");
  }
});

test("[service-checks-02099e] a preflight from the UI answers 204", async () => {
  const base = await apps.start();
  const preflight = (origin: string): Promise<Response> =>
    fetch(`${base}/graphql`, {
      method: "OPTIONS",
      headers: {
        origin,
        "access-control-request-method": "POST",
        "access-control-request-headers": "content-type",
      },
    });
  const allowed = await preflight(appUrl);
  expect(allowed.status).toBe(204);
  expect(allowed.headers.get("access-control-allow-methods")).toBe("GET, POST");
  expect(allowed.headers.get("access-control-allow-headers")).toBe(
    "Content-Type",
  );
  expect(allowed.headers.get("access-control-max-age")).toBe("600");
  const other = await preflight("http://elsewhere.test");
  expect(other.headers.get("access-control-allow-origin")).toBeNull();
  expect(other.headers.get("access-control-allow-methods")).toBeNull();
});
