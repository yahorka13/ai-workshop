import { index, pgTable, text, timestamp } from "drizzle-orm/pg-core";
import { timestamps } from "./timestamps";
import { users } from "./users";

// How a user signs in: for email and password, the provider `credential`
// with the password's hash. The token columns are better-auth's, unused here.
export const accounts = pgTable(
  "accounts",
  {
    id: text("id").primaryKey(),
    userId: text("user_id")
      .notNull()
      .references(() => users.id, { onDelete: "cascade" }),
    accountId: text("account_id").notNull(),
    providerId: text("provider_id").notNull(),
    password: text("password"),
    accessToken: text("access_token"),
    refreshToken: text("refresh_token"),
    idToken: text("id_token"),
    accessTokenExpiresAt: timestamp("access_token_expires_at", {
      withTimezone: true,
    }),
    refreshTokenExpiresAt: timestamp("refresh_token_expires_at", {
      withTimezone: true,
    }),
    scope: text("scope"),
    ...timestamps,
  },
  (table) => [index("accounts_user_id_index").on(table.userId)],
);
