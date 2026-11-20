import { index, pgTable, text, timestamp } from "drizzle-orm/pg-core";
import { timestamps } from "./timestamps";

// better-auth's short-lived values; email and password sign-in writes none,
// but better-auth needs the table.
export const verifications = pgTable(
  "verifications",
  {
    id: text("id").primaryKey(),
    identifier: text("identifier").notNull(),
    value: text("value").notNull(),
    expiresAt: timestamp("expires_at", { withTimezone: true }).notNull(),
    ...timestamps,
  },
  (table) => [index("verifications_identifier_index").on(table.identifier)],
);
