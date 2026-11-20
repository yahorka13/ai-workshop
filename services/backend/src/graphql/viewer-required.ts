// The guard for data that needs a signed-in user: every field that needs one
// calls it first, so a signed-out request gets one well-known error.
import { GraphQLError } from "graphql";
import type { Viewer } from "../viewer";
import type { Context } from "./builder";

/** The request's viewer; throws UNAUTHENTICATED when no one is signed in. */
export function viewerRequired(context: Context): Viewer {
  if (context.viewer !== null) return context.viewer;
  throw new GraphQLError("Sign in to see this.", {
    extensions: { code: "UNAUTHENTICATED" },
  });
}
