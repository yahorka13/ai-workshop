import { expect, spyOn, test } from "bun:test";
import { useApolloClient } from "@apollo/client/react";
import { MockedProvider } from "@apollo/client/testing/react";
import { render } from "@testing-library/react";
import type { ReactElement } from "react";
import { useSession, type Session } from "@/hooks/useSession";
import { ApiOriginContext } from "@/services/graphql/origin";

test("without an API origin, signing in fails and signing out sends nothing", async () => {
  const fetchSpy = spyOn(globalThis, "fetch");
  let session: Session | undefined;
  function Probe(): ReactElement {
    session = useSession();
    return <p>probe</p>;
  }
  render(
    <MockedProvider>
      <Probe />
    </MockedProvider>,
  );
  expect(await session?.signIn("demo@example.com", "password")).toBe("failed");
  await session?.signOut();
  expect(fetchSpy).not.toHaveBeenCalled();
  fetchSpy.mockRestore();
});

test("a sign-in whose cache refresh fails reports the failure", async () => {
  const fetchSpy = spyOn(globalThis, "fetch").mockResolvedValue(
    Response.json({}, { status: 200 }),
  );
  let session: Session | undefined;
  function Probe(): ReactElement {
    session = useSession();
    const client = useApolloClient();
    spyOn(client, "resetStore").mockRejectedValue(new TypeError("offline"));
    return <p>probe</p>;
  }
  render(
    <ApiOriginContext value="http://api">
      <MockedProvider>
        <Probe />
      </MockedProvider>
    </ApiOriginContext>,
  );
  expect(await session?.signIn("demo@example.com", "password")).toBe("failed");
  fetchSpy.mockRestore();
});
