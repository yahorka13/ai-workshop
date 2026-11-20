import { expect, test } from "bun:test";
import { ConfigError, parseConfig } from "../../src/config";

const database = {
  POSTGRES_URL: "postgres://postgres:5432",
  POSTGRES_DB: "app",
  POSTGRES_USER: "app",
  POSTGRES_PASSWORD: "secret",
  APP_URL: "http://127.0.0.1:11100",
  API_URL: "http://127.0.0.1:4000",
  AUTH_SECRET: "s".repeat(32),
};
const appUrl = "http://127.0.0.1:11100";
const auth = {
  apiUrl: "http://127.0.0.1:4000",
  authSecret: "s".repeat(32),
  localStack: false,
};
const url = "postgres://app:secret@postgres:5432/app";

test("the port defaults to 4000", () => {
  expect(parseConfig(database)).toEqual({
    port: 4000,
    databaseUrl: url,
    appUrl,
    ...auth,
  });
});

test("a valid port is read", () => {
  expect(parseConfig({ ...database, PORT: "4100" })).toEqual({
    port: 4100,
    databaseUrl: url,
    appUrl,
    ...auth,
  });
});

test.each(["abc", "0", "70000", "", "4000.5"])(
  "[service-checks-836a90] PORT=%p is refused, naming PORT",
  (value) => {
    expect(() => parseConfig({ ...database, PORT: value })).toThrow(
      ConfigError,
    );
    expect(() => parseConfig({ ...database, PORT: value })).toThrow(
      /^Invalid environment: PORT$/,
    );
  },
);

test("a missing database variable is named, with every other problem, and no value", () => {
  let message = "";
  try {
    parseConfig({ ...database, POSTGRES_DB: undefined, PORT: "abc" });
  } catch (error) {
    if (error instanceof ConfigError) message = error.message;
  }
  expect(message).toContain("PORT");
  expect(message).toContain("Set POSTGRES_DB");
  expect(message).not.toContain("secret");
});

test("APP_URL is kept as its bare origin", () => {
  expect(
    parseConfig({ ...database, APP_URL: "https://ui.example.test/" }).appUrl,
  ).toBe("https://ui.example.test");
});

test.each([
  undefined,
  "",
  "ftp://ui.test",
  "http://user:pw@ui.test/path",
  "http://user:pw@ui.test",
  "http://user@ui.test",
  "http://ui.test/path",
  "http://ui.test/?q=1",
  "http://ui.test/#top",
  "not a url",
])(
  "[service-checks-8ab0f6] APP_URL=%p is refused, naming APP_URL and not its value",
  (value) => {
    let message = "";
    try {
      parseConfig({ ...database, APP_URL: value });
    } catch (error) {
      if (error instanceof ConfigError) message = error.message;
    }
    expect(message).toContain("APP_URL");
    if (value !== undefined && value !== "")
      expect(message).not.toContain(value);
  },
);

test("API_URL is kept as its bare origin", () => {
  expect(
    parseConfig({ ...database, API_URL: "https://api.example.test/" }).apiUrl,
  ).toBe("https://api.example.test");
});

test.each([undefined, "", "http://api.test/path", "not a url"])(
  "API_URL=%p is refused, naming API_URL and not its value",
  (value) => {
    let message = "";
    try {
      parseConfig({ ...database, API_URL: value });
    } catch (error) {
      if (error instanceof ConfigError) message = error.message;
    }
    expect(message).toContain("API_URL must be a bare http(s) origin");
    if (value !== undefined && value !== "")
      expect(message).not.toContain(value);
  },
);

test.each([undefined, "", "x".repeat(31)])(
  "AUTH_SECRET=%p is refused, naming AUTH_SECRET and not its value",
  (value) => {
    let message = "";
    try {
      parseConfig({ ...database, AUTH_SECRET: value });
    } catch (error) {
      if (error instanceof ConfigError) message = error.message;
    }
    expect(message).toContain("AUTH_SECRET must be at least 32 characters");
    if (value !== undefined && value !== "")
      expect(message).not.toContain(value);
  },
);

test.each([
  ["1", true],
  ["0", false],
  ["", false],
  [undefined, false],
])("FACTORY_LOCAL_STACK=%p makes localStack %p", (value, expected) => {
  expect(
    parseConfig({ ...database, FACTORY_LOCAL_STACK: value }).localStack,
  ).toBe(expected);
});

test("a database problem alone is refused, though every other variable is valid", () => {
  expect(() => parseConfig({ ...database, POSTGRES_URL: "not a url" })).toThrow(
    ConfigError,
  );
});
