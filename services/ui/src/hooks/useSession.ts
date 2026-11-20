import { useApolloClient } from "@apollo/client/react";
import { use } from "react";
import { signIn, signOut, type AuthResult } from "@/services/auth";
import { ApiOriginContext } from "@/services/graphql/origin";

export type Session = {
  signIn: (email: string, password: string) => Promise<AuthResult>;
  /** Ends the session; the app shows signed out even when the API failed. */
  signOut: () => Promise<void>;
};

/** Signing in and out. Both reset the cache, so the viewer is read again. */
export function useSession(): Session {
  const origin = use(ApiOriginContext);
  const client = useApolloClient();
  return {
    signIn: async (email, password) => {
      if (origin === undefined) return "failed";
      const result = await signIn(origin, email, password);
      if (result !== "ok") return result;
      // Reading the viewer again needs the API too; if that fails, say so.
      return client.resetStore().then(
        () => "ok" as const,
        () => "failed" as const,
      );
    },
    signOut: async () => {
      if (origin !== undefined) await signOut(origin);
      await client.clearStore();
    },
  };
}
