// Sign-in, sign-out and sessions, served by better-auth at /api/auth: email
// and password only, and no sign-up, since the seed creates every user.
// Session length, refresh, cookie attributes and password hashing are
// better-auth's defaults on purpose: a feature that needs other values says so
// in its design. The cookie is HttpOnly and SameSite=Lax; the UI is another
// port of the same host, so its credentialed requests carry it.
import { betterAuth, type BetterAuthOptions } from "better-auth";
import { drizzleAdapter } from "better-auth/adapters/drizzle";
import { fromNodeHeaders } from "better-auth/node";
import type { RequestHandler } from "express";
import type { IncomingHttpHeaders } from "node:http";
import type { AnyDatabase } from "./db/connection";
import { accounts, sessions, users, verifications } from "./db/schema";
import { viewerFromSession, type Viewer } from "./viewer";

/** Where the auth routes are mounted on the API. */
export const AUTH_PATH = "/api/auth";

// The only header better-auth reads a client's address from. The API sets it
// itself, so a client cannot pick its own rate-limit bucket.
const CLIENT_ADDRESS = "x-factory-client-address";

/**
 * Puts the request's address (Express's `req.ip`) where better-auth reads it,
 * replacing anything the client sent. Mount it before the auth handler.
 */
export const clientAddress: RequestHandler = (request, _response, next) => {
  // Stryker disable next-line StringLiteral: requests without an address share one bucket, whatever its name
  request.headers[CLIENT_ADDRESS] = request.ip ?? "";
  next();
};

export type AuthOptions = {
  db: AnyDatabase;
  /** The UI's origin, the only one allowed to sign in. */
  appUrl: string;
  /** The API's own public origin. */
  apiUrl: string;
  secret: string;
  /** False on a local stack, where the e2e suite signs in many times. */
  rateLimited: boolean;
};

function authOptions(options: AuthOptions): BetterAuthOptions {
  return {
    basePath: AUTH_PATH,
    baseURL: options.apiUrl,
    secret: options.secret,
    trustedOrigins: [options.appUrl],
    emailAndPassword: { enabled: true, disableSignUp: true },
    database: drizzleAdapter(options.db, {
      provider: "pg",
      schema: {
        user: users,
        session: sessions,
        account: accounts,
        verification: verifications,
      },
    }),
    telemetry: { enabled: false },
    // better-auth's default limits: 3 sign-ins per 10 seconds per address.
    rateLimit: { enabled: options.rateLimited },
    advanced: {
      ipAddress: { ipAddressHeaders: [CLIENT_ADDRESS] },
      // Explicit, because better-auth skips both checks when NODE_ENV=test.
      disableOriginCheck: false,
      disableCSRFCheck: false,
    },
  };
}

export type Auth = ReturnType<typeof betterAuth<BetterAuthOptions>>;

/** The better-auth instance over the backend's own tables. */
export function createAuth(options: AuthOptions): Auth {
  return betterAuth(authOptions(options));
}

/**
 * Resolves a request's viewer from the session its headers carry. A lookup
 * that fails, such as with the database down, means no viewer, so queries
 * that need no user, like `health`, still answer.
 */
export function sessionViewer(
  auth: Auth,
): (headers: IncomingHttpHeaders) => Promise<Viewer | null> {
  return async (headers) =>
    auth.api
      .getSession({ headers: fromNodeHeaders(headers) })
      .then(viewerFromSession, () => null);
}
