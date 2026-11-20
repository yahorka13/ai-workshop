import { request as requests } from "@playwright/test";
import { DEMO } from "./auth";

/* The API as a client reaches it: the slot's published API port, from the
   app's origin, as the browser sends its requests. */

function env(name: string): string {
  const value = process.env[name];
  if (value === undefined || value === "") {
    throw new Error(`${name} is not set: run the suite with bin/e2e`);
  }
  return value;
}

export const api = env("E2E_API_URL");
export const origin = env("E2E_BASE_URL");

/** A GraphQL answer from a fresh client that sends only the given cookie. */
export async function graphql(
  query: string,
  cookie?: string,
): Promise<unknown> {
  const client = await requests.newContext();
  try {
    const response = await client.post(`${api}/graphql`, {
      headers: {
        Origin: origin,
        ...(cookie === undefined ? {} : { Cookie: cookie }),
      },
      data: { query },
    });
    return await response.json();
  } finally {
    await client.dispose();
  }
}

/** Signs the demo user in over the API and returns the session cookie. */
export async function demoSession(): Promise<string> {
  const client = await requests.newContext();
  try {
    const response = await client.post(`${api}/api/auth/sign-in/email`, {
      headers: { Origin: origin },
      data: { email: DEMO.email, password: DEMO.password },
    });
    return (response.headers()["set-cookie"] ?? "").split(";")[0] ?? "";
  } finally {
    await client.dispose();
  }
}
