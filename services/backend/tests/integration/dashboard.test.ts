import { afterEach, expect, test } from "bun:test";
import { z } from "zod";
import { appServers, graphql, signedInCookie } from "../support/server";

const apps = appServers();
afterEach(apps.close);

const STATS = "{ dashboard { totalUsers signUps { day count } } }";

const statsAnswer = z.object({
  data: z.object({
    dashboard: z.object({
      totalUsers: z.number(),
      signUps: z.array(z.object({ day: z.string(), count: z.number() })),
    }),
  }),
});

// The answer to a signed-out request: no data, one UNAUTHENTICATED error.
const unauthenticated = {
  data: null,
  errors: [
    {
      message: "Sign in to see this.",
      extensions: { code: "UNAUTHENTICATED" },
    },
  ],
};

test("[dashboard-57cd2b] a signed-in request reads the stats", async () => {
  const base = await apps.startSeeded();
  const answer = statsAnswer.parse(
    await graphql(base, STATS, await signedInCookie(base)),
  );
  const { totalUsers, signUps } = answer.data.dashboard;
  expect(totalUsers).toBe(1);
  expect(signUps).toHaveLength(7);
  expect(signUps.at(-1)?.day).toBe(new Date().toISOString().slice(0, 10));
  expect(signUps.reduce((sum, entry) => sum + entry.count, 0)).toBe(1);
});

test.each([undefined, "better-auth.session_token=forged"])(
  "[dashboard-5ee8ff] a signed-out request is refused: %p",
  async (cookie) => {
    const base = await apps.startSeeded();
    expect(await graphql(base, STATS, cookie)).toMatchObject(unauthenticated);
  },
);

test("a session lookup that fails is refused, not a server error", async () => {
  const cookie = await signedInCookie(await apps.startSeeded());
  const broken = await apps.startOnClosedDatabase();
  expect(await graphql(broken, STATS, cookie)).toMatchObject(unauthenticated);
});

test("a signed-out query with health and the dashboard answers no data", async () => {
  const base = await apps.startSeeded();
  expect(
    await graphql(base, "{ health { ok } dashboard { totalUsers } }"),
  ).toMatchObject(unauthenticated);
});
