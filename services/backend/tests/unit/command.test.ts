import { expect, spyOn, test } from "bun:test";
import { runCommand } from "../../src/db/command";

const database = {
  POSTGRES_URL: "postgres://127.0.0.1:1",
  POSTGRES_DB: "app",
  POSTGRES_USER: "app",
  POSTGRES_PASSWORD: "secret",
};

function recorder(): {
  io: { log: (line: string) => void; error: (line: string) => void };
  lines: string[];
} {
  const lines: string[] = [];
  return {
    lines,
    io: {
      log: (line) => lines.push(`out: ${line}`),
      error: (line) => lines.push(`err: ${line}`),
    },
  };
}

test("--help prints the usage and runs nothing", async () => {
  const { io, lines } = recorder();
  let ran = false;
  const code = await runCommand(
    "usage: x",
    () => {
      ran = true;
      return Promise.resolve();
    },
    { argv: ["bun", "x.ts", "--help"], env: {}, io },
  );
  expect(code).toBe(0);
  expect(ran).toBe(false);
  expect(lines).toEqual(["out: usage: x"]);
});

test("work that succeeds exits 0 with the pool it was given, then closes it", async () => {
  const { io, lines } = recorder();
  let given = false;
  let ended: (() => void) | undefined;
  const code = await runCommand(
    "usage: x",
    (pool) => {
      given = pool.options.max === 1;
      const end = spyOn(pool, "end");
      ended = () => {
        expect(end).toHaveBeenCalledTimes(1);
      };
      return Promise.resolve();
    },
    { argv: [], env: database, io },
  );
  expect(code).toBe(0);
  expect(given).toBe(true);
  ended?.();
  expect(lines).toEqual([]);
});

test("a failure, or a missing database variable, exits 1 printing only its message", async () => {
  const { io, lines } = recorder();
  const failing = await runCommand(
    "usage: x",
    () => Promise.reject(new Error("it broke")),
    { argv: [], env: database, io },
  );
  const unconfigured = await runCommand("usage: x", () => Promise.resolve(), {
    argv: [],
    env: {},
    io,
  });
  expect(failing).toBe(1);
  expect(unconfigured).toBe(1);
  expect(lines[0]).toBe("err: it broke");
  expect(lines[1]).toContain("err: Set POSTGRES_URL");
});
