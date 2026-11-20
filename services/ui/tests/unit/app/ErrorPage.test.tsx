import { expect, spyOn, test } from "bun:test";
import { fireEvent, render, screen } from "@testing-library/react";
import { createMemoryRouter, RouterProvider } from "react-router";
import { ErrorPage } from "@/app/ErrorPage";
import { expectErrorScreen } from "../../support/error-screen";

function Boom(): never {
  throw new Error("secret detail");
}

test("[app-shell-1efddc] a thrown error shows the error screen without its details", () => {
  const quiet = spyOn(console, "error").mockImplementation(() => undefined);
  const router = createMemoryRouter(
    [{ path: "/", element: <Boom />, errorElement: <ErrorPage /> }],
    { initialEntries: ["/"] },
  );
  render(<RouterProvider router={router} />);
  quiet.mockRestore();

  expectErrorScreen();
  expect(
    screen.getByText("This page failed to load. Reload to try again."),
  ).toBeDefined();
  expect(document.body.textContent).not.toContain("secret detail");

  const reload = spyOn(window.location, "reload").mockImplementation(
    () => undefined,
  );
  fireEvent.click(screen.getByRole("button", { name: "Reload" }));
  expect(reload).toHaveBeenCalledTimes(1);
  reload.mockRestore();
});
