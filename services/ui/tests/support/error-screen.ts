import { expect } from "bun:test";
import { screen } from "@testing-library/react";

// The error screen is showing: its heading, Reload and a link home.
export function expectErrorScreen(): void {
  expect(
    screen.getByRole("heading", { name: "Something went wrong" }),
  ).toBeDefined();
  expect(screen.getByRole("button", { name: "Reload" })).toBeDefined();
  expect(
    screen.getByRole("link", { name: "Go to home" }).getAttribute("href"),
  ).toBe("/");
}
