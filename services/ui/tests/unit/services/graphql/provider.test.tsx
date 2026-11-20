import { expect, test } from "bun:test";
import type { ApolloClient } from "@apollo/client";
import { useApolloClient } from "@apollo/client/react";
import { render } from "@testing-library/react";
import { use, type ReactElement } from "react";
import { ApiOriginContext } from "@/services/graphql/origin";
import { ApiProvider } from "@/services/graphql/provider";

// Keeps the client and origin each render sees.
function recorder(): {
  seen: { client: ApolloClient; origin: string | undefined }[];
  Probe: () => ReactElement;
} {
  const seen: { client: ApolloClient; origin: string | undefined }[] = [];
  const Probe = (): ReactElement => {
    seen.push({ client: useApolloClient(), origin: use(ApiOriginContext) });
    return <p>probe</p>;
  };
  return { seen, Probe };
}

test("the provider keeps its client for one origin and makes a new one for another", () => {
  const { seen, Probe } = recorder();
  const { rerender } = render(
    <ApiProvider origin="http://a.test">
      <Probe />
    </ApiProvider>,
  );
  rerender(
    <ApiProvider origin="http://a.test">
      <Probe key="again" />
    </ApiProvider>,
  );
  rerender(
    <ApiProvider origin="http://b.test">
      <Probe />
    </ApiProvider>,
  );
  const [first, second, third] = seen;
  expect(second?.client).toBe(first?.client);
  expect(third?.client).not.toBe(first?.client);
  expect(third?.origin).toBe("http://b.test");
});
