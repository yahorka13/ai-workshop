import { expect, test } from "bun:test";
import { users } from "../../src/db/schema";
import { databaseUserStats } from "../../src/db/user-stats";
import { migratedDatabase } from "../support/database";

const since = new Date("2026-11-11T00:00:00Z");

test("users are counted in all, and per UTC day from since", async () => {
  const db = await migratedDatabase();
  const created = [
    "2026-11-17T00:00:00Z",
    "2026-11-17T12:00:00Z",
    "2026-11-16T23:59:59.999Z",
    "2026-11-01T00:00:00Z",
    "2026-11-11T00:00:00Z", // exactly since: counted
  ];
  await db.insert(users).values(
    created.map((at, index) => ({
      id: `u${String(index)}`,
      name: `User ${String(index)}`,
      email: `user${String(index)}@example.com`,
      createdAt: new Date(at),
    })),
  );
  const stats = databaseUserStats(db);
  expect(await stats.total()).toBe(5);
  const days = await stats.createdPerDay(since);
  expect(days.toSorted((a, b) => a.day.localeCompare(b.day))).toEqual([
    { day: "2026-11-11", count: 1 },
    { day: "2026-11-16", count: 1 },
    { day: "2026-11-17", count: 2 },
  ]);
});

test("an empty users table counts nothing", async () => {
  const stats = databaseUserStats(await migratedDatabase());
  expect(await stats.total()).toBe(0);
  expect(await stats.createdPerDay(since)).toEqual([]);
});
