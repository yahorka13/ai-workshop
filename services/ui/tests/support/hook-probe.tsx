import { MockedProvider } from "@apollo/client/testing/react";
import type { MockLink } from "@apollo/client/testing";
import { render } from "@testing-library/react";
import type { ReactElement } from "react";
import { ApiOriginContext } from "@/services/graphql/origin";

/**
 * Renders a data hook's state as JSON in an <output> (role status), with
 * these mocked answers and this API origin (undefined: not configured).
 */
export function showHook(
  useHook: () => unknown,
  mocks: MockLink.MockedResponse[],
  origin: string | undefined,
): void {
  function Probe(): ReactElement {
    return <output>{JSON.stringify(useHook())}</output>;
  }
  render(
    <ApiOriginContext value={origin}>
      <MockedProvider mocks={mocks}>
        <Probe />
      </MockedProvider>
    </ApiOriginContext>,
  );
}
