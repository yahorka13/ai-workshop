// Who a request is from: the signed-in user its session cookie names, or no
// one. better-auth's answer is untrusted like any other, so it is parsed.
import { z } from "zod";

export type Viewer = { id: string; name: string; email: string };

const session = z.object({
  user: z.object({ id: z.string(), name: z.string(), email: z.string() }),
});

/** The viewer of a better-auth session answer, or null for anything else. */
export function viewerFromSession(answer: unknown): Viewer | null {
  const parsed = session.safeParse(answer);
  if (!parsed.success) return null;
  const { id, name, email } = parsed.data.user;
  return { id, name, email };
}
