import { expect, test } from "bun:test";
import { render, screen } from "@testing-library/react";
import { Input } from "@/components/ui/input";

test("an input passes its type and attributes through", () => {
  render(<Input type="email" aria-label="Email" aria-invalid required />);
  const input = screen.getByRole("textbox", { name: "Email" });
  expect(input.getAttribute("type")).toBe("email");
  expect(input.dataset.slot).toBe("input");
  expect(input.getAttribute("aria-invalid")).toBe("true");
  expect(input.hasAttribute("required")).toBe(true);
});
