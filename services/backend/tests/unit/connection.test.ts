import { expect, test } from "bun:test";
import {
  createDatabase,
  createPool,
  databaseUrl,
} from "../../src/db/connection";
import { at } from "../support/defined";

const env = {
  POSTGRES_URL: "postgres://postgres:5432",
  POSTGRES_DB: "app",
  POSTGRES_USER: "owner",
  POSTGRES_PASSWORD: "p@ss:w/rd",
};

function thrown(run: () => unknown): string | null {
  try {
    run();
  } catch (error) {
    return error instanceof Error ? error.message : String(error);
  }
  return null;
}

test("the backend connects to the location in POSTGRES_URL with encoded credentials", () => {
  expect(databaseUrl(env)).toBe(
    "postgres://owner:p%40ss%3Aw%2Frd@postgres:5432/app",
  );
});

test("a location without a port keeps PostgreSQL's default", () => {
  expect(databaseUrl({ ...env, POSTGRES_URL: "postgresql://db.example" })).toBe(
    "postgres://owner:p%40ss%3Aw%2Frd@db.example/app",
  );
});

test("connection parameters in POSTGRES_URL are kept, for a server that needs TLS", () => {
  expect(
    databaseUrl({
      ...env,
      POSTGRES_URL: "postgres://db.example:6432?sslmode=require",
    }),
  ).toBe(
    "postgres://owner:p%40ss%3Aw%2Frd@db.example:6432/app?sslmode=require",
  );
});

test("a missing variable is named and no value is echoed", () => {
  for (const name of [
    "POSTGRES_URL",
    "POSTGRES_DB",
    "POSTGRES_USER",
    "POSTGRES_PASSWORD",
  ]) {
    expect(thrown(() => databaseUrl({ ...env, [name]: undefined }))).toBe(
      `Set ${name}`,
    );
    expect(thrown(() => databaseUrl({ ...env, [name]: "" }))).toBe(
      `Set ${name}`,
    );
  }
});

test("POSTGRES_URL is a location only: no credentials, database or other scheme", () => {
  for (const location of [
    "postgres://user:secret@postgres:5432",
    "postgres://user@postgres:5432",
    "postgres://:secret@postgres:5432",
    "postgres://",
    "postgres://postgres:5432#app",
    "postgres://postgres:5432/app",
    "mysql://postgres:5432",
    "not a url",
  ]) {
    const message = thrown(() =>
      databaseUrl({ ...env, POSTGRES_URL: location }),
    );
    expect(message).toBe(
      "POSTGRES_URL must be postgres://<host>[:<port>] with no credentials or path",
    );
    expect(message).not.toContain("secret");
  }
});

test("a dropped connection is logged once by its message and never ends the process", () => {
  const lines: string[] = [];
  const pool = createPool("postgres://u:p@127.0.0.1:1/db", (line) =>
    lines.push(line),
  );
  const handlers: [string, (error: Error) => void][] = [];
  const client = {
    on: (event: string, listener: (error: Error) => void): void => {
      handlers.push([event, listener]);
    },
  };
  pool.emit("connect", client);
  const [event, listener] = at(handlers, 0, "client listeners");
  expect(event).toBe("error");
  listener(new Error("terminating connection"));
  expect(lines).toEqual(["database connection error: terminating connection"]);
  expect(() => pool.emit("error", new Error("idle client"))).not.toThrow();
});

test("the database runs over the pool it is given", async () => {
  const pool = createPool("postgres://u:p@127.0.0.1:1/db", () => undefined);
  expect(createDatabase(pool).$client).toBe(pool);
  await pool.end();
});

test("a location may end in a slash", () => {
  expect(
    databaseUrl({ ...env, POSTGRES_URL: "postgres://postgres:5432/" }),
  ).toBe(databaseUrl(env));
});
