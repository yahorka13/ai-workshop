import { expect, spyOn, test } from "bun:test";
import type { MockLink } from "@apollo/client/testing";
import { screen } from "@testing-library/react";
import { useViewer } from "@/hooks/useViewer";
import { ViewerQuery } from "@/services/graphql/viewer";
import { showHook } from "../../support/hook-probe";

function show(
  mocks: MockLink.MockedResponse[],
  origin: string | undefined,
): void {
  showHook(useViewer, mocks, origin);
}

const answer = (viewer: unknown): MockLink.MockedResponse => ({
  request: { query: ViewerQuery },
  result: { data: { viewer } },
  delay: 20,
});

const demo = {
  __typename: "Viewer",
  id: "u1",
  name: "Demo User",
  email: "demo@example.com",
};

test("a signed-in viewer loads, then is signed in", async () => {
  show([answer(demo)], "http://api.test");
  expect(screen.getByRole("status").textContent).toBe('{"status":"loading"}');
  expect(
    await screen.findByText(
      JSON.stringify({
        status: "signedIn",
        viewer: { id: "u1", name: "Demo User", email: "demo@example.com" },
      }),
    ),
  ).toBeDefined();
});

test.each([
  ["no viewer", answer(null)],
  ["a malformed answer", answer({ __typename: "Viewer", id: 1 })],
  [
    "a failed request",
    { request: { query: ViewerQuery }, error: new Error("offline") },
  ],
] as const)("%s is signed out", async (_case, mock) => {
  show([mock], "http://api.test");
  expect(await screen.findByText('{"status":"signedOut"}')).toBeDefined();
});

test("without an API origin the viewer is signed out and nothing is sent", () => {
  const fetchSpy = spyOn(globalThis, "fetch");
  show([], undefined);
  expect(screen.getByRole("status").textContent).toBe('{"status":"signedOut"}');
  expect(fetchSpy).not.toHaveBeenCalled();
  fetchSpy.mockRestore();
});
