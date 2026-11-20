import { expect, test } from "bun:test";
import { serviceRoot } from "../fixtures";

// The entry's connection to a real database is proven by bin/up on a stack;
// these runs need none.
function seed(
  args: string[],
  env: Record<string, string>,
): Bun.SyncSubprocess<"pipe", "pipe"> {
  return Bun.spawnSync([process.execPath, "tooling/seed.ts", ...args], {
    cwd: serviceRoot,
    env: { PATH: process.env.PATH ?? "", ...env },
    stdout: "pipe",
    stderr: "pipe",
  });
}

test("the seed command prints its usage and needs no database", () => {
  const run = seed(["--help"], {});
  expect(run.exitCode).toBe(0);
  expect(run.stdout.toString()).toContain("usage: bun tooling/seed.ts");
  expect(run.stdout.toString()).toContain("FACTORY_LOCAL_STACK=1");
});

test("[auth-2bc8df] the seed command refuses a stack bin/up did not start", () => {
  const run = seed([], {
    POSTGRES_URL: "postgres://127.0.0.1:1",
    POSTGRES_DB: "app",
    POSTGRES_USER: "app",
    POSTGRES_PASSWORD: "secret",
  });
  expect(run.exitCode).toBe(1);
  expect(run.stderr.toString()).toContain(
    "seed: refusing to seed a stack bin/up did not start",
  );
});
