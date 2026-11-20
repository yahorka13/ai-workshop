import { expect, test } from "bun:test";
import { render, screen } from "@testing-library/react";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";

test("a label names the field it is for", () => {
  render(
    <>
      <Label htmlFor="email">Email</Label>
      <Input id="email" />
    </>,
  );
  expect(screen.getByLabelText("Email").id).toBe("email");
  expect(screen.getByText("Email").dataset.slot).toBe("label");
});
