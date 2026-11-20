import { expect, spyOn, test } from "bun:test";
import { MockedProvider } from "@apollo/client/testing/react";
import type { MockLink } from "@apollo/client/testing";
import { render, screen } from "@testing-library/react";
import { ApiStatus, ApiStatusBadge } from "@/components/ApiStatus";
import { ApiProvider } from "@/services/graphql/provider";
import { ApiOriginContext } from "@/services/graphql/origin";
import { HealthQuery } from "@/services/graphql/health";

function withApi(mocks: MockLink.MockedResponse[]): void {
  render(
    <ApiOriginContext value="http://api.test">
      <MockedProvider mocks={mocks}>
        <ApiStatus />
      </MockedProvider>
    </ApiOriginContext>,
  );
}

const health = (ok: boolean): MockLink.MockedResponse => ({
  request: { query: HealthQuery },
  result: { data: { health: { __typename: "Health", ok } } },
  delay: 20,
});

test("[app-shell-3b054c] a healthy API shows checking, then online", async () => {
  withApi([health(true)]);
  expect(screen.getByRole("status").textContent).toBe("Checking API");
  expect(await screen.findByText("API online")).toBeDefined();
  expect(screen.getByRole("status").dataset.state).toBe("online");
});

test("[app-shell-ca45c7] an unhealthy API shows offline", async () => {
  withApi([health(false)]);
  expect(await screen.findByText("API offline")).toBeDefined();
});

test("[app-shell-ca45c7] a malformed health answer shows offline", async () => {
  withApi([
    {
      request: { query: HealthQuery },
      result: { data: { health: { __typename: "Health", ok: "yes" } } },
    },
  ]);
  expect(await screen.findByText("API offline")).toBeDefined();
});

test("[app-shell-ca45c7] a failed request shows offline", async () => {
  withApi([
    { request: { query: HealthQuery }, error: new Error("connection refused") },
  ]);
  expect(await screen.findByText("API offline")).toBeDefined();
});

test("[app-shell-ca45c7] a GraphQL error shows offline", async () => {
  withApi([
    {
      request: { query: HealthQuery },
      result: { errors: [{ message: "boom" }] },
    },
  ]);
  expect(await screen.findByText("API offline")).toBeDefined();
});

test("[app-shell-c757ea] without an API origin it shows not configured and sends nothing", async () => {
  const fetchSpy = spyOn(globalThis, "fetch");
  render(
    <ApiProvider origin={undefined}>
      <ApiStatus />
    </ApiProvider>,
  );
  expect(screen.getByRole("status").textContent).toBe("API not configured");
  await new Promise((resolve) => setTimeout(resolve, 20));
  expect(screen.getByRole("status").textContent).toBe("API not configured");
  expect(fetchSpy).not.toHaveBeenCalled();
  fetchSpy.mockRestore();
});

test("the provider gives a configured origin its client", async () => {
  const fetchSpy = spyOn(globalThis, "fetch").mockResolvedValue(
    Response.json({ data: { health: { __typename: "Health", ok: true } } }),
  );
  render(
    <ApiProvider origin="http://api.test">
      <ApiStatus />
    </ApiProvider>,
  );
  expect(await screen.findByText("API online")).toBeDefined();
  expect(fetchSpy.mock.calls[0]?.[0]).toBe("http://api.test/graphql");
  fetchSpy.mockRestore();
});

test.each([
  ["checking", "bg-muted-foreground animate-pulse"],
  ["online", "bg-success"],
  ["offline", "bg-destructive"],
  ["unconfigured", "bg-muted-foreground"],
] as const)("the %s badge's dot is coloured %p", (state, colour) => {
  render(<ApiStatusBadge state={state} />);
  const dot = screen.getByRole("status").querySelector("[aria-hidden]");
  expect(dot?.className).toContain(colour);
});
