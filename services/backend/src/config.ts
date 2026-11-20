// The backend's configuration, read once from the environment at startup.
// Errors name the variables at fault, never a value.
import { z } from "zod";
import { databaseUrl } from "./db/connection";

export type Config = {
  port: number;
  databaseUrl: string;
  appUrl: string;
  /** The API's own public origin, where the UI reaches it. */
  apiUrl: string;
  /** Signs and encrypts the session cookies. */
  authSecret: string;
  /** A stack bin/up started, which only the session's Compose file marks. */
  localStack: boolean;
};

export class ConfigError extends Error {
  constructor(problems: readonly string[]) {
    super(`Invalid environment: ${problems.join(", ")}`);
  }
}

// A bare http(s) origin: no credentials, path, query or fragment.
const origin = z
  .string()
  .refine((value) => URL.canParse(value))
  .transform((value) => new URL(value))
  .refine(
    (url) =>
      ["http:", "https:"].includes(url.protocol) &&
      `${url.username}${url.password}${url.search}${url.hash}` === "" &&
      url.pathname === "/",
  )
  .transform((url) => url.origin);

const schema = z.object({
  PORT: z.coerce.number().int().min(1).max(65535).default(4000),
  // The UI's origin, the only one CORS allows.
  APP_URL: origin,
  API_URL: origin,
  AUTH_SECRET: z.string().min(32),
});

// What each invalid variable is reported as, in this order.
const problemOf: Record<keyof z.input<typeof schema>, string> = {
  PORT: "PORT",
  APP_URL: "APP_URL must be a bare http(s) origin",
  API_URL: "API_URL must be a bare http(s) origin",
  AUTH_SECRET: "AUTH_SECRET must be at least 32 characters",
};

/** The database URL, or undefined with its problem added to `problems`. */
function databaseUrlOrProblem(
  env: Record<string, string | undefined>,
  problems: string[],
): string | undefined {
  try {
    return databaseUrl(env);
  } catch (error) {
    problems.push(error instanceof Error ? error.message : String(error));
    return undefined;
  }
}

/** The configuration, or a ConfigError naming every problem. */
export function parseConfig(env: Record<string, string | undefined>): Config {
  const parsed = schema.safeParse(env); // an empty PORT is coerced to 0, refused
  const invalid = new Set(parsed.error?.issues.map((issue) => issue.path[0]));
  const problems = Object.entries(problemOf)
    .filter(([name]) => invalid.has(name))
    .map(([, problem]) => problem);
  const url = databaseUrlOrProblem(env, problems);
  if (!parsed.success || url === undefined) throw new ConfigError(problems);
  return {
    port: parsed.data.PORT,
    databaseUrl: url,
    appUrl: parsed.data.APP_URL,
    apiUrl: parsed.data.API_URL,
    authSecret: parsed.data.AUTH_SECRET,
    localStack: env.FACTORY_LOCAL_STACK === "1",
  };
}
