import { expect, test } from "bun:test";
import { ApolloClient, ApolloLink, InMemoryCache } from "@apollo/client";
import { ApolloProvider } from "@apollo/client/react";
import { act, render, screen } from "@testing-library/react";
import type { ReactElement } from "react";
import { NEVER } from "rxjs";
import { useDashboard } from "@/hooks/useDashboard";
import { useHealth } from "@/hooks/useHealth";
import { useViewer } from "@/hooks/useViewer";

function Probe(): ReactElement {
  return (
    <output>
      {useHealth()} {useViewer().status} {useDashboard().status}
    </output>
  );
}

test("with no API origin, the hooks ask the API nothing", async () => {
  const asked: string[] = [];
  const link = new ApolloLink((operation) => {
    asked.push(operation.operationName ?? "");
    return NEVER;
  });
  render(
    <ApolloProvider
      client={new ApolloClient({ link, cache: new InMemoryCache() })}
    >
      <Probe />
    </ApolloProvider>,
  );
  await act(async () => {
    await new Promise((resolve) => setTimeout(resolve, 10));
  });
  expect(screen.getByRole("status").textContent).toBe(
    "unconfigured signedOut failed",
  );
  expect(asked).toEqual([]);
});
