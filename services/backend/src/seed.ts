// The demo users every local stack signs in with. bin/seed runs this, through
// tooling/seed.ts, inside the backend container of a stack bin/up started; the
// FACTORY_LOCAL_STACK marker only that stack sets is what tells it so. The
// credentials are fixed on purpose: they are not a secret, because no other
// stack ever holds them.
//
// It writes the rows better-auth reads, hashing the password with better-auth's
// own hasher, and touches nothing that exists, so a rerun is safe.
import { hashPassword } from "better-auth/crypto";
import { inArray } from "drizzle-orm";
import type { AnyDatabase } from "./db/connection";
import { accounts, users } from "./db/schema";

const DEMO_USERS = [
  { email: "demo@example.com", name: "Demo User", password: "password" },
] as const;

export class LocalOnlyError extends Error {
  constructor() {
    super("seed: refusing to seed a stack bin/up did not start");
  }
}

export type SeedReport = { created: string[]; existing: string[] };

/** Creates every demo user that does not exist; refuses unless on a local stack. */
export async function seedDemoUsers(
  db: AnyDatabase,
  env: Record<string, string | undefined>,
): Promise<SeedReport> {
  if (env.FACTORY_LOCAL_STACK !== "1") throw new LocalOnlyError();
  const emails = DEMO_USERS.map((user) => user.email);
  return db.transaction(async (tx) => {
    const found = await tx
      .select({ email: users.email })
      .from(users)
      .where(inArray(users.email, emails));
    const existing = new Set(found.map((user) => user.email));
    const created: string[] = [];
    for (const user of DEMO_USERS) {
      if (existing.has(user.email)) continue;
      const id = crypto.randomUUID();
      await tx.insert(users).values({ id, email: user.email, name: user.name });
      await tx.insert(accounts).values({
        id: crypto.randomUUID(),
        userId: id,
        accountId: id,
        providerId: "credential",
        password: await hashPassword(user.password),
      });
      created.push(user.email);
    }
    return { created, existing: emails.filter((email) => existing.has(email)) };
  });
}
