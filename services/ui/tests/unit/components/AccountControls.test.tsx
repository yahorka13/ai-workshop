import { afterEach, expect, spyOn, test } from "bun:test";
import { fireEvent, screen } from "@testing-library/react";
import { AccountControls } from "@/components/AccountControls";
import { demo, visitAs } from "../../support/signed-in";

const fetchSpy = spyOn(globalThis, "fetch");
afterEach(() => {
  fetchSpy.mockReset();
});

function show(): ReturnType<typeof visitAs> {
  return visitAs(demo, "/", [
    { path: "/", element: <AccountControls name="Demo User" /> },
    { path: "/login", element: <h1>Login</h1> },
  ]);
}

test.each([200, 500])(
  "signing out (answered %p) ends the session and opens the login page",
  async (status) => {
    fetchSpy.mockResolvedValue(Response.json({}, { status }));
    const router = show();
    expect(screen.getByText("Demo User")).toBeDefined();
    fireEvent.click(screen.getByRole("button", { name: "Sign out" }));
    expect(await screen.findByRole("heading", { name: "Login" })).toBeDefined();
    expect(router.state.location.pathname).toBe("/login");
    expect(fetchSpy.mock.calls[0]?.[0]).toBe(
      "http://api.test/api/auth/sign-out",
    );
  },
);
