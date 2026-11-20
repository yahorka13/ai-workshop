// The database schema: every table, one module per table, re-exported here.
// Change it, then run `bun run db:generate` (AGENTS.md: database).
export { accounts } from "./accounts";
export { sessions } from "./sessions";
export { users } from "./users";
export { verifications } from "./verifications";
