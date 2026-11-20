import { expect, test } from "bun:test";
import { dashboard, type SignUpDay, type UserStats } from "../../src/dashboard";

// A UserStats that answers the given rows and records the `since` it is asked for.
function fakeStats(
  total: number,
  rows: SignUpDay[],
): UserStats & { since: Date[] } {
  const since: Date[] = [];
  return {
    since,
    total: () => Promise.resolve(total),
    createdPerDay: (from) => {
      since.push(from);
      return Promise.resolve(rows);
    },
  };
}

const now = new Date("2026-11-17T22:30:00Z");

test("the window is the 7 UTC days ending on now's day, oldest first", async () => {
  const stats = fakeStats(0, []);
  const answer = await dashboard(stats, now);
  expect(stats.since).toEqual([new Date("2026-11-11T00:00:00.000Z")]);
  expect(answer.signUps.map((entry) => entry.day)).toEqual([
    "2026-11-11",
    "2026-11-12",
    "2026-11-13",
    "2026-11-14",
    "2026-11-15",
    "2026-11-16",
    "2026-11-17",
  ]);
});

test("days with sign-ups count them, and the rest are zero", async () => {
  const stats = fakeStats(5, [
    { day: "2026-11-17", count: 2 },
    { day: "2026-11-12", count: 1 },
    { day: "2026-11-10", count: 9 },
  ]);
  const answer = await dashboard(stats, now);
  expect(answer.totalUsers).toBe(5);
  expect(answer.signUps.map((entry) => entry.count)).toEqual([
    0, 1, 0, 0, 0, 0, 2,
  ]);
});

test("now defaults to the current time", async () => {
  const answer = await dashboard(fakeStats(0, []));
  expect(answer.signUps.at(-1)?.day).toBe(
    new Date().toISOString().slice(0, 10),
  );
});
