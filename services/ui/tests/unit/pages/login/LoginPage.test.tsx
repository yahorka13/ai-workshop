import { afterEach, expect, spyOn, test } from "bun:test";
import { MockedProvider } from "@apollo/client/testing/react";
import {
  fireEvent,
  render,
  screen,
  waitFor,
  within,
} from "@testing-library/react";
import {
  createMemoryRouter,
  NavigationType,
  RouterProvider,
} from "react-router";
import { LoginPage } from "@/pages/login/LoginPage";
import { HealthQuery } from "@/services/graphql/health";
import { ApiOriginContext } from "@/services/graphql/origin";

const fetchSpy = spyOn(globalThis, "fetch");
afterEach(() => {
  fetchSpy.mockReset();
});

function visit(path: string): ReturnType<typeof createMemoryRouter> {
  const router = createMemoryRouter(
    [
      { path: "/login", element: <LoginPage /> },
      { path: "*", element: <h1>Landed</h1> },
    ],
    { initialEntries: [path] },
  );
  render(
    <ApiOriginContext value="http://api">
      <MockedProvider
        mocks={[
          {
            request: { query: HealthQuery },
            result: { data: { health: { __typename: "Health", ok: true } } },
            maxUsageCount: Number.POSITIVE_INFINITY,
          },
        ]}
      >
        <RouterProvider router={router} />
      </MockedProvider>
    </ApiOriginContext>,
  );
  return router;
}

function submit(email: string, password: string): void {
  fireEvent.change(screen.getByLabelText("Email"), {
    target: { value: email },
  });
  fireEvent.change(screen.getByLabelText("Password"), {
    target: { value: password },
  });
  fireEvent.click(screen.getByRole("button", { name: "Sign in" }));
}

// Answers the sign-in with this status.
function answer(status: number): void {
  fetchSpy.mockResolvedValue(Response.json({}, { status }));
}

test("the login page asks for an email and a password", () => {
  answer(200);
  visit("/login");
  expect(screen.getByRole("heading", { name: "Sign in" })).toBeDefined();
  const email = screen.getByLabelText("Email");
  expect(document.activeElement).toBe(email);
  expect(email.getAttribute("autocomplete")).toBe("username");
  expect(screen.getByLabelText("Password").getAttribute("autocomplete")).toBe(
    "current-password",
  );
  expect(screen.getByRole("status")).toBeDefined();
});

test("signing in posts the credentials once while pending, then opens next", async () => {
  let release = (): void => undefined;
  fetchSpy.mockReturnValue(
    new Promise((resolve) => {
      release = () => {
        resolve(Response.json({}, { status: 200 }));
      };
    }),
  );
  const router = visit("/login?next=%2Fno-such-page%3Fx%3D1");
  submit("demo@example.com", "password");
  const button = await screen.findByRole("button", { name: "Signing in…" });
  expect(button.hasAttribute("disabled")).toBe(true);
  fireEvent.click(button);
  expect(fetchSpy).toHaveBeenCalledTimes(1);
  const [url, init] = fetchSpy.mock.calls[0] ?? [];
  expect(url).toBe("http://api/api/auth/sign-in/email");
  const body = typeof init?.body === "string" ? init.body : "";
  expect(JSON.parse(body)).toEqual({
    email: "demo@example.com",
    password: "password",
  });
  release();
  expect(await screen.findByRole("heading", { name: "Landed" })).toBeDefined();
  expect(router.state.location.pathname).toBe("/no-such-page");
  expect(router.state.location.search).toBe("?x=1");
  // The login page is replaced: going back does not return to it.
  expect(router.state.historyAction).toBe(NavigationType.Replace);
});

test.each(["//evil.example", "https://evil.example", "/\\evil.example"])(
  "[auth-cea8c2] next=%p is ignored for /",
  async (next) => {
    answer(200);
    const router = visit(`/login?next=${encodeURIComponent(next)}`);
    submit("demo@example.com", "password");
    expect(
      await screen.findByRole("heading", { name: "Landed" }),
    ).toBeDefined();
    expect(router.state.location.pathname).toBe("/");
  },
);

test("refused credentials say so and stay on the page", async () => {
  answer(401);
  const router = visit("/login");
  submit("demo@example.com", "wrong");
  const alert = await screen.findByRole("alert");
  expect(alert.textContent).toBe("Wrong email or password.");
  expect(router.state.location.pathname).toBe("/login");
  await waitFor(() => {
    expect(
      screen.getByRole("button", { name: "Sign in" }).hasAttribute("disabled"),
    ).toBe(false);
  });
});

test.each([500, 0])(
  "[auth-9f85cb] a failed sign-in (%p) says the server could not be reached",
  async (status) => {
    if (status === 0) fetchSpy.mockRejectedValue(new TypeError("offline"));
    else answer(status);
    const router = visit("/login");
    submit("demo@example.com", "password");
    const alert = await screen.findByRole("alert");
    expect(
      within(alert).getByText("Couldn't reach the server. Try again."),
    ).toBeDefined();
    expect(router.state.location.pathname).toBe("/login");
  },
);
