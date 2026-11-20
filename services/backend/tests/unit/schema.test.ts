import { expect, test } from "bun:test";
import { getTableConfig, type PgTable } from "drizzle-orm/pg-core";
import { accounts, sessions, users, verifications } from "../../src/db/schema";
import { at } from "../support/defined";

function config(table: PgTable): ReturnType<typeof getTableConfig> {
  return getTableConfig(table);
}

test.each([
  ["sessions", sessions],
  ["accounts", accounts],
] as const)(
  "a user's %s go with the user, and are found by user",
  (name, table) => {
    const { foreignKeys, indexes } = config(table);
    const key = at(foreignKeys, 0, `${name} foreign keys`);
    expect(key.reference().foreignTable).toBe(users);
    expect(key.onDelete).toBe("cascade");
    expect(indexes.map((index) => index.config.name)).toEqual([
      `${name}_user_id_index`,
    ]);
  },
);

test("verifications are found by identifier", () => {
  expect(
    config(verifications).indexes.map((index) => index.config.name),
  ).toEqual(["verifications_identifier_index"]);
});

test("a user's columns are the ones the migrations create", () => {
  expect(config(users).columns.map((column) => column.name)).toEqual([
    "id",
    "name",
    "email",
    "email_verified",
    "image",
    "created_at",
    "updated_at",
  ]);
});
