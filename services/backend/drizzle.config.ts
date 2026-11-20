import { defineConfig } from "drizzle-kit";

// Generation and snapshot checks never connect; the runner in src/db applies
// migrations itself, so the credential here stays empty unless one is exported.
export default defineConfig({
  dialect: "postgresql",
  schema: "./src/db/schema/index.ts",
  out: "./src/db/migrations",
  dbCredentials: { url: process.env.DATABASE_URL ?? "" },
});
