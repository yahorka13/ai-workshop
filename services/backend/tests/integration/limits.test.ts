import { afterEach, expect, test } from "bun:test";
import { getIntrospectionQuery } from "graphql";
import { z } from "zod";
import { appServers, appUrl, graphql, signedInCookie } from "../support/server";

const apps = appServers();
afterEach(apps.close);

// 101 aliases of health { ok }: 202 fields, each alias a health probe.
const WIDE = `{ ${Array.from({ length: 101 }, (_, i) => `h${i}: health { ok }`).join(" ")} }`;

test("[contracts-e79819] too many fields over HTTP are refused before any resolver runs", async () => {
  let probes = 0;
  const base = await apps.start(() => {
    probes += 1;
    return Promise.resolve(true);
  });
  const response = await fetch(`${base}/graphql`, {
    method: "POST",
    headers: { "content-type": "application/json", origin: appUrl },
    body: JSON.stringify({ query: WIDE }),
  });
  expect(response.status).toBe(400);
  const body = z.record(z.string(), z.unknown()).parse(await response.json());
  expect(body).not.toHaveProperty("data");
  expect(body).toMatchObject({
    errors: [
      {
        message: "Query selects 202 fields; the limit is 100.",
        extensions: { code: "QUERY_TOO_COMPLEX" },
      },
    ],
  });
  expect(probes).toBe(0);
});

test("[contracts-d1de56] [contracts-4f83fa] the UI's dashboard query passes the limits", async () => {
  const base = await apps.startSeeded();
  const answer = z
    .object({
      data: z.object({ dashboard: z.object({ totalUsers: z.number() }) }),
    })
    .parse(
      await graphql(
        base,
        "{ dashboard { totalUsers signUps { day count } } }",
        await signedInCookie(base),
      ),
    );
  expect(answer.data.dashboard.totalUsers).toBe(1);
});

test("[contracts-f0fd4e] the introspection query answers over HTTP", async () => {
  const base = await apps.start();
  expect(await graphql(base, getIntrospectionQuery())).toMatchObject({
    data: { __schema: { queryType: { name: "Query" } } },
  });
});
