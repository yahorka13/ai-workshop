import { expect, spyOn, test } from "bun:test";
import { render, screen } from "@testing-library/react";
import * as reactRouter from "react-router";
import { App } from "@/app/App";

test("App routes the browser's location", () => {
  // This build has no API, so no one is signed in: the login page keeps the
  // requested path.
  window.history.replaceState({}, "", "/somewhere-else");
  render(<App />);
  expect(screen.getByRole("heading", { name: "Sign in" })).toBeDefined();
  expect(window.location.search).toBe("?next=%2Fsomewhere-else");
  window.history.replaceState({}, "", "/");
});

test("App creates its router once across re-renders", () => {
  const create = spyOn(reactRouter, "createBrowserRouter");
  try {
    const { rerender } = render(<App />);
    rerender(<App />);
    expect(create).toHaveBeenCalledTimes(1);
  } finally {
    create.mockRestore();
  }
});
