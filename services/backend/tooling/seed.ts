// The seed command bin/seed runs inside the backend container: creates the
// demo users (src/seed.ts) on the database this container serves.
import { createDatabase } from "../src/db/connection";
import { runCommand } from "../src/db/command";
import { seedDemoUsers } from "../src/seed";

const usage = `usage: bun tooling/seed.ts
       bun tooling/seed.ts --help

Create each demo user that does not exist in the database POSTGRES_DB at
POSTGRES_URL, connecting as POSTGRES_USER with POSTGRES_PASSWORD, and print
what it created and what existed. It refuses unless FACTORY_LOCAL_STACK=1,
which only the stack bin/up starts sets. Run it through bin/seed.`;

if (import.meta.main) {
  process.exitCode = await runCommand(usage, async (pool) => {
    const report = await seedDemoUsers(createDatabase(pool), process.env);
    if (report.created.length > 0)
      console.log(`Created: ${report.created.join(", ")}`);
    if (report.existing.length > 0)
      console.log(`Exists: ${report.existing.join(", ")}`);
  });
}
