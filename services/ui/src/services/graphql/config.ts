// Where the API is, from the build's environment (VITE_API_URL). Anything but
// a bare http(s) origin leaves it not configured.
import { z } from "zod";

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

/** The API's origin from `VITE_API_URL`, or undefined when it is not one. */
export function apiUrl(
  env: Readonly<Record<string, unknown>>,
): string | undefined {
  return origin.safeParse(env.VITE_API_URL).data;
}

const env: Readonly<Record<string, unknown>> = import.meta.env;

/** This build's API origin. */
export const apiOrigin = apiUrl(env);
