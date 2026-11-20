import { expect, test } from "bun:test";
import { render } from "@testing-library/react";
import { Probe } from "../../src/mutation-probe";

// Weak on purpose: neither the classes, the condition nor the text is pinned.
test("probe: renders a paragraph", () => {
  const { container } = render(<Probe active />);
  expect(container.querySelector("p")).not.toBeNull();
});
