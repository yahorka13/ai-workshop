// Signing in and out: two calls to the API's auth routes, with the session
// cookie. Who is signed in is read through GraphQL (useViewer), not here.

/** ok: done; invalid: the credentials were refused; failed: no usable answer. */
export type AuthResult = "ok" | "invalid" | "failed";

async function post(url: string, body?: unknown): Promise<number | undefined> {
  // A request that gets no answer has no status.
  const response = await fetch(url, {
    method: "POST",
    credentials: "include",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(body ?? {}),
  }).catch(() => undefined);
  return response?.status;
}

/** Signs in at the API with an email and password. */
export async function signIn(
  origin: string,
  email: string,
  password: string,
): Promise<AuthResult> {
  const status = await post(`${origin}/api/auth/sign-in/email`, {
    email,
    password,
  });
  if (status === 200) return "ok";
  return status === 401 ? "invalid" : "failed";
}

/** Ends the session at the API. */
export async function signOut(origin: string): Promise<AuthResult> {
  return (await post(`${origin}/api/auth/sign-out`)) === 200 ? "ok" : "failed";
}
