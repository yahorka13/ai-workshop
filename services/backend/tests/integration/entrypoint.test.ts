import { expect, spyOn, test } from "bun:test";
import { ConfigError } from "../../src/config";
import { failStartup } from "../../src/server";
import { serviceRoot } from "../fixtures";
import { freshIndex } from "../support/entrypoint";

test("[service-checks-836a90] an invalid PORT stops startup, naming PORT", async () => {
  const backend = Bun.spawn([process.execPath, "src/index.ts"], {
    cwd: serviceRoot,
    env: { ...process.env, PORT: "abc" },
    stdout: "pipe",
    stderr: "pipe",
  });
  expect(await backend.exited).toBe(1);
  expect(await new Response(backend.stderr).text()).toContain("PORT");
});

test("a startup failure other than configuration is rethrown", () => {
  const boom = new Error("boom");
  expect(() => failStartup(boom)).toThrow(boom);
});

test("a configuration failure exits 1 with its message", () => {
  const log = spyOn(console, "error").mockImplementation(() => undefined);
  const exit = (code: number): never => {
    throw new Error(`exit ${code}`);
  };
  expect(() => failStartup(new ConfigError(["PORT"]), exit)).toThrow("exit 1");
  expect(log).toHaveBeenCalledWith("Invalid environment: PORT");
  log.mockRestore();
});

// Nothing listens on port 1, so the probe fails at once.
const unreachable = {
  POSTGRES_URL: "postgres://127.0.0.1:1",
  POSTGRES_DB: "app",
  POSTGRES_USER: "app",
  POSTGRES_PASSWORD: "secret",
  APP_URL: "http://127.0.0.1:11100",
  API_URL: "http://127.0.0.1:4000",
  AUTH_SECRET: "s".repeat(32),
};

test("the entry point serves /health on the configured port, probing the configured database", async () => {
  const log = spyOn(console, "log").mockImplementation(() => undefined);
  const previous = { ...process.env };
  const port = String(20000 + Math.floor(Math.random() * 20000));
  Object.assign(process.env, unreachable, { PORT: port });
  const { server } = await freshIndex();
  try {
    const response = await fetch(`http://127.0.0.1:${port}/health`);
    expect(response.status).toBe(503);
    expect(await response.json()).toEqual({ ok: false });
    expect(log).toHaveBeenCalledWith(`backend listening on ${port}`);
  } finally {
    server.close();
    for (const name of [...Object.keys(unreachable), "PORT"])
      if (previous[name] === undefined)
        Reflect.deleteProperty(process.env, name);
      else process.env[name] = previous[name];
    log.mockRestore();
  }
});
