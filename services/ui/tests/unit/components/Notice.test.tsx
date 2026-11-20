import { expect, test } from "bun:test";
import { render, screen } from "@testing-library/react";
import { Notice } from "@/components/Notice";

test("a notice shows its title as the page heading, its body and its actions", () => {
  render(
    <Notice title="Page not found" body="Nothing lives at this address.">
      <button type="button">Go to home</button>
    </Notice>,
  );
  expect(
    screen.getByRole("heading", { level: 1, name: "Page not found" }),
  ).toBeDefined();
  expect(screen.getByText("Nothing lives at this address.")).toBeDefined();
  expect(screen.getByRole("button", { name: "Go to home" })).toBeDefined();
});
