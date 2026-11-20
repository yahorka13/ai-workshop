import { expect, test } from "bun:test";
import { render, screen } from "@testing-library/react";
import { Button } from "@/components/ui/button";

test("a button carries its variant and size", () => {
  render(
    <Button variant="outline" size="sm">
      Save
    </Button>,
  );
  const button = screen.getByRole("button", { name: "Save" });
  expect(button.dataset.variant).toBe("outline");
  expect(button.dataset.size).toBe("sm");
  expect(button.dataset.slot).toBe("button");
});

test("asChild renders its child with the button's styling", () => {
  render(
    <Button asChild>
      <a href="/">Home</a>
    </Button>,
  );
  const link = screen.getByRole("link", { name: "Home" });
  expect(link.dataset.variant).toBe("default");
  expect(link.className).toContain("inline-flex");
});

test("a button is styled by its variant and size, keeping its own classes", () => {
  render(
    <Button variant="outline" size="sm" className="w-full">
      Save
    </Button>,
  );
  const button = screen.getByRole("button", { name: "Save" });
  expect(button.className).toContain("border-border");
  expect(button.className).toContain("h-7");
  expect(button.className).toContain("w-full");
  expect(button.className).not.toContain("bg-primary");
});

test("a button without a variant or size is the default one", () => {
  render(<Button>Go</Button>);
  const button = screen.getByRole("button", { name: "Go" });
  expect(button.dataset.variant).toBe("default");
  expect(button.dataset.size).toBe("default");
  expect(button.className).toContain("bg-primary");
  expect(button.className).toContain("h-8");
});
