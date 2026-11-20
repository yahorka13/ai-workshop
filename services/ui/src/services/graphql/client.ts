// The one GraphQL client. Every query shows what the cache holds and refreshes
// it (cache-and-network), and every request carries the session cookie.
// Without an API origin every operation fails at once,
// and no request leaves the page.
import {
  ApolloClient,
  ApolloLink,
  HttpLink,
  InMemoryCache,
} from "@apollo/client";
import { throwError } from "rxjs";

const unconfigured = new ApolloLink(() =>
  throwError(() => new Error("The API origin is not configured.")),
);

export function createClient(origin: string | undefined): ApolloClient {
  return new ApolloClient({
    link:
      origin === undefined
        ? unconfigured
        : new HttpLink({ uri: `${origin}/graphql`, credentials: "include" }),
    cache: new InMemoryCache(),
    defaultOptions: { watchQuery: { fetchPolicy: "cache-and-network" } },
  });
}
