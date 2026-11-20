import { expect, test } from "bun:test";
import { render, screen } from "@testing-library/react";
import { Card, CardContent } from "@/components/ui/card";

test("a card holds its content and carries its size", () => {
  render(
    <Card size="sm" aria-label="Sign in">
      <CardContent>Fields</CardContent>
    </Card>,
  );
  const card = screen.getByLabelText("Sign in");
  expect(card.dataset.slot).toBe("card");
  expect(card.dataset.size).toBe("sm");
  expect(screen.getByText("Fields").dataset.slot).toBe("card-content");
});

test("a card without a size is the default one", () => {
  render(<Card aria-label="Plain" />);
  expect(screen.getByLabelText("Plain").dataset.size).toBe("default");
});
