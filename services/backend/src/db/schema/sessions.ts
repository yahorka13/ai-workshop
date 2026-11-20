import { index, pgTable, text, timestamp } from "drizzle-orm/pg-core";
import { timestamps } from "./timestamps";
import { users } from "./users";

// A signed-in browser, found by the token its session cookie carries.
export const sessions = pgTable(
  "sessions",
  {
    id: text("id").primaryKey(),
    userId: text("user_id")
      .notNull()
      .references(() => users.id, { onDelete: "cascade" }),
    token: text("token").notNull().unique(),
    expiresAt: timestamp("expires_at", { withTimezone: true }).notNull(),
    ipAddress: text("ip_address"),
    userAgent: text("user_agent"),
    ...timestamps,
  },
  (table) => [index("sessions_user_id_index").on(table.userId)],
);
