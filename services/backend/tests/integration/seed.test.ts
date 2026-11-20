import { expect, test } from "bun:test";
import { verifyPassword } from "better-auth/crypto";
import { eq } from "drizzle-orm";
import { accounts, users } from "../../src/db/schema";
import { LocalOnlyError, seedDemoUsers } from "../../src/seed";
import { at } from "../support/defined";
import { migratedDatabase } from "../support/database";

const local = { FACTORY_LOCAL_STACK: "1" };

test("[auth-f0bdba] a second seed changes nothing", async () => {
  const db = await migratedDatabase();
  expect(await seedDemoUsers(db, local)).toEqual({
    created: ["demo@example.com"],
    existing: [],
  });
  expect(await seedDemoUsers(db, local)).toEqual({
    created: [],
    existing: ["demo@example.com"],
  });
  const rows = await db.select().from(users);
  expect(rows).toHaveLength(1);
  const user = at(rows, 0, "users");
  expect(user).toMatchObject({ email: "demo@example.com", name: "Demo User" });
  const account = at(
    await db.select().from(accounts).where(eq(accounts.userId, user.id)),
    0,
    "accounts",
  );
  expect(account.providerId).toBe("credential");
  expect(account.accountId).toBe(user.id);
  expect(
    await verifyPassword({
      hash: account.password ?? "",
      password: "password",
    }),
  ).toBe(true);
});

test("a seed keeps an existing demo user's changed password", async () => {
  const db = await migratedDatabase();
  await seedDemoUsers(db, local);
  await db.update(accounts).set({ password: "changed-hash" });
  await seedDemoUsers(db, local);
  const account = at(await db.select().from(accounts), 0, "accounts");
  expect(account.password).toBe("changed-hash");
});

test.each([{}, { FACTORY_LOCAL_STACK: "0" }, { FACTORY_LOCAL_STACK: "" }])(
  "[auth-2bc8df] the seed refuses a stack bin/up did not start: %p",
  async (env) => {
    const db = await migratedDatabase();
    const error: unknown = await seedDemoUsers(db, env).catch(
      (thrown: unknown) => thrown,
    );
    expect(error).toBeInstanceOf(LocalOnlyError);
    expect(error).toHaveProperty(
      "message",
      "seed: refusing to seed a stack bin/up did not start",
    );
    expect(await db.select().from(users)).toHaveLength(0);
  },
);
