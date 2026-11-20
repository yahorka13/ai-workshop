import { ApolloProvider } from "@apollo/client/react";
import { useMemo, type ReactElement, type ReactNode } from "react";
import { createClient } from "./client";
import { ApiOriginContext } from "./origin";

/** The GraphQL client for `origin`, and the origin itself, for everything inside. */
export function ApiProvider({
  origin,
  children,
}: {
  origin: string | undefined;
  children: ReactNode;
}): ReactElement {
  const client = useMemo(() => createClient(origin), [origin]);
  return (
    <ApiOriginContext value={origin}>
      <ApolloProvider client={client}>{children}</ApolloProvider>
    </ApiOriginContext>
  );
}
