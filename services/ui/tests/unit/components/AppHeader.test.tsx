import { expect, test } from "bun:test";
import { screen, within } from "@testing-library/react";
import { AppHeader } from "@/components/AppHeader";
import { demo, visitAs } from "../../support/signed-in";

const header = [{ path: "/", element: <AppHeader /> }];

test("the header shows the signed-in viewer's account controls", async () => {
  visitAs(demo, "/", header);
  const banner = screen.getByRole("banner");
  expect(await within(banner).findByText("Demo User")).toBeDefined();
  expect(
    within(banner).getByRole("button", { name: "Sign out" }),
  ).toBeDefined();
});

test("the header of a signed-out viewer has no account controls", async () => {
  visitAs(null, "/", header);
  const banner = screen.getByRole("banner");
  expect(await within(banner).findByText("API online")).toBeDefined();
  expect(within(banner).queryByRole("button", { name: "Sign out" })).toBeNull();
});
