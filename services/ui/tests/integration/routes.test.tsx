import { expect, spyOn, test } from "bun:test";
import { render, screen, within } from "@testing-library/react";
import {
  createMemoryRouter,
  RouterProvider,
  type RouteObject,
} from "react-router";
import { createRoutes } from "@/app/routes";
import { ApiProvider } from "@/services/graphql/provider";
import { expectErrorScreen } from "../support/error-screen";
import { demo, visitAs } from "../support/signed-in";

function visit(path: string): void {
  visitAs(demo, path, createRoutes());
}

test("[app-shell-af1ebe] [dashboard-9e4f6d] the home screen is the dashboard, in the layout", async () => {
  visit("/");
  const banner = await screen.findByRole("banner");
  expect(within(banner).getByText("Factory")).toBeDefined();
  expect(within(banner).getByText("Demo User")).toBeDefined();
  const nav = within(banner).getByRole("navigation", { name: "Main" });
  const dashboard = within(nav).getByRole("link", { name: "Dashboard" });
  expect(dashboard.getAttribute("aria-current")).toBe("page");
  expect(dashboard.className).toContain("bg-muted");
  const main = screen.getByRole("main");
  expect(
    within(main).getByRole("heading", { name: "Dashboard" }),
  ).toBeDefined();
  expect(await within(main).findByText("12")).toBeDefined();
});

test("[app-shell-c88136] an unknown path shows the not-found screen", async () => {
  visit("/no-such-page");
  expect(await screen.findByRole("banner")).toBeDefined();
  const main = screen.getByRole("main");
  expect(
    within(main).getByRole("heading", { name: "Page not found" }),
  ).toBeDefined();
  expect(
    within(main).getByRole("link", { name: "Go to home" }).getAttribute("href"),
  ).toBe("/");
  const dashboard = within(screen.getByRole("navigation")).getByRole("link", {
    name: "Dashboard",
  });
  expect(dashboard.getAttribute("aria-current")).toBeNull();
  expect(dashboard.className).not.toContain("bg-muted");
  expect(
    within(main).getByText("There is no page at this address."),
  ).toBeDefined();
});

test("[auth-891d75] a signed-out visit opens the login page, keeping the path", async () => {
  const router = visitAs(null, "/", createRoutes());
  expect(await screen.findByRole("heading", { name: "Sign in" })).toBeDefined();
  expect(screen.queryByRole("banner")).toBeNull();
  expect(router.state.location.pathname).toBe("/login");
  expect(router.state.location.search).toBe("?next=%2F");
});

test("[auth-5ad99e] a signed-out deep link keeps its path and query", async () => {
  const router = visitAs(null, "/no-such-page?x=1", createRoutes());
  expect(await screen.findByRole("heading", { name: "Sign in" })).toBeDefined();
  expect(router.state.location.search).toBe(
    `?next=${encodeURIComponent("/no-such-page?x=1")}`,
  );
});

test("[auth-49f567] a signed-in user opening the login page goes to next or home", async () => {
  const router = visitAs(demo, "/login?next=%2Fno-such-page", createRoutes());
  expect(
    await screen.findByRole("heading", { name: "Page not found" }),
  ).toBeDefined();
  expect(router.state.location.pathname).toBe("/no-such-page");
});

test("while the viewer loads, neither the app nor the login page shows", () => {
  visit("/");
  expect(screen.queryByRole("main")).toBeNull();
  expect(screen.queryByRole("heading", { name: "Sign in" })).toBeNull();
});

test("while the viewer loads, the login page shows nothing either", () => {
  visitAs(null, "/login", createRoutes());
  expect(screen.queryByRole("main")).toBeNull();
  expect(screen.queryByRole("heading", { name: "Sign in" })).toBeNull();
});

test("[app-shell-c757ea] a build without an API origin shows the login page and sends nothing", () => {
  const fetchSpy = spyOn(globalThis, "fetch");
  const router = createMemoryRouter(createRoutes(), { initialEntries: ["/"] });
  render(
    <ApiProvider origin={undefined}>
      <RouterProvider router={router} />
    </ApiProvider>,
  );
  expect(screen.getByRole("heading", { name: "Sign in" })).toBeDefined();
  expect(screen.getByRole("status").textContent).toBe("API not configured");
  expect(fetchSpy).not.toHaveBeenCalled();
  fetchSpy.mockRestore();
});

function Boom(): never {
  throw new Error("secret detail");
}

// The app's own route tree with its index screen replaced by one that throws.
function throwingIndex(routes: RouteObject[]): RouteObject[] {
  return routes.map((route): RouteObject => {
    if (route.index === true) return { ...route, element: <Boom /> };
    if (route.children === undefined) return route;
    return { ...route, children: throwingIndex(route.children) };
  });
}

test("[app-shell-1efddc] a screen that throws shows the app's error screen in the layout", async () => {
  const quiet = spyOn(console, "error").mockImplementation(() => undefined);
  visitAs(demo, "/", throwingIndex(createRoutes()));
  expect(
    await screen.findByRole("heading", { name: "Something went wrong" }),
  ).toBeDefined();
  quiet.mockRestore();
  expect(screen.getByRole("banner")).toBeDefined();
  expect(document.body.textContent).not.toContain("secret detail");
});

test("[app-shell-585d60] a layout that throws shows the error screen without the layout", () => {
  // Without ApiProvider the session's viewer query has no client and throws.
  const quiet = spyOn(console, "error").mockImplementation(() => undefined);
  const router = createMemoryRouter(createRoutes(), { initialEntries: ["/"] });
  render(<RouterProvider router={router} />);
  quiet.mockRestore();
  expectErrorScreen();
  expect(screen.queryByRole("banner")).toBeNull();
  expect(document.body.textContent).not.toContain(
    "Unexpected Application Error",
  );
  expect(document.body.textContent).not.toContain("Invariant Violation");
  // The message Apollo throws without a client.
  expect(document.body.textContent).not.toContain("An error occurred!");
});
