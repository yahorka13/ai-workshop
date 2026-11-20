import { boolean, pgTable, text } from "drizzle-orm/pg-core";
import { timestamps } from "./timestamps";

// A person who signs in. better-auth reads and writes it under these field
// names; the seed is the only thing that creates one.
export const users = pgTable("users", {
  id: text("id").primaryKey(),
  name: text("name").notNull(),
  email: text("email").notNull().unique(),
  emailVerified: boolean("email_verified").notNull().default(false),
  // Stryker disable next-line StringLiteral: Drizzle names a column without a name after its key, "image"
  image: text("image"),
  ...timestamps,
});
