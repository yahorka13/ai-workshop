import { expect, spyOn, test } from "bun:test";
import { databaseProbe } from "../../src/db/probe";
import { checkHealth } from "../../src/health";

test("a probe that answers true is healthy", async () => {
  expect(await checkHealth(() => Promise.resolve(true))).toEqual({ ok: true });
});

test("a probe that answers false or rejects is unhealthy", async () => {
  expect(await checkHealth(() => Promise.resolve(false))).toEqual({
    ok: false,
  });
  expect(await checkHealth(() => Promise.reject(new Error("down")))).toEqual({
    ok: false,
  });
});

test("a probe that does not settle in time is unhealthy", async () => {
  const started = Date.now();
  expect(await checkHealth(() => new Promise(() => undefined), 20)).toEqual({
    ok: false,
  });
  expect(Date.now() - started).toBeLessThan(1000);
});

test("the database probe selects 1 and turns a failure into false", async () => {
  const sent: string[] = [];
  const up = databaseProbe({
    query: (sql: string) => {
      sent.push(sql);
      return Promise.resolve({});
    },
  });
  expect(await up()).toBe(true);
  expect(sent).toEqual(["select 1"]);
  const down = databaseProbe({
    query: () => Promise.reject(new Error("connection refused")),
  });
  expect(await down()).toBe(false);
});

test("a probe that answers in time leaves no timer behind", async () => {
  const cleared = spyOn(globalThis, "clearTimeout");
  try {
    await checkHealth(() => Promise.resolve(true), 60_000);
    expect(cleared).toHaveBeenCalledTimes(1);
  } finally {
    cleared.mockRestore();
  }
});
