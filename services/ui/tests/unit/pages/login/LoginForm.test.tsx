import { expect, mock, test } from "bun:test";
import {
  act,
  fireEvent,
  render,
  screen,
  waitFor,
} from "@testing-library/react";
import { LoginForm } from "@/pages/login/LoginForm";
import type { AuthResult } from "@/services/auth";

type SignIn = (email: string, password: string) => Promise<AuthResult>;

// The form, and a way to submit it the way a browser does.
function form(onSignIn: SignIn): { submit: () => boolean } {
  render(<LoginForm onSignIn={onSignIn} />);
  const element = screen.getByRole("button").closest("form");
  if (!element) throw new Error("no form");
  return { submit: () => fireEvent.submit(element) };
}

const invalidity = (): (string | null)[] =>
  ["Email", "Password"].map((label) =>
    screen.getByLabelText(label).getAttribute("aria-invalid"),
  );

test("a fresh form shows no problem and marks no field", () => {
  form(() => Promise.resolve<AuthResult>("ok"));
  expect(screen.queryByRole("alert")).toBeNull();
  expect(invalidity()).toEqual([null, null]);
});

test("submitting keeps the browser on the page", () => {
  const { submit } = form(() => Promise.resolve<AuthResult>("ok"));
  expect(submit()).toBe(false);
});

test("a submit while one is pending sends nothing more", async () => {
  const onSignIn = mock<SignIn>(() => new Promise(() => undefined));
  const { submit } = form(onSignIn);
  submit();
  expect(
    await screen.findByRole("button", { name: "Signing in…" }),
  ).toBeDefined();
  submit();
  expect(onSignIn).toHaveBeenCalledTimes(1);
});

test("a successful sign-in stays pending and shows no problem", async () => {
  const onSignIn = mock<SignIn>(() => Promise.resolve<AuthResult>("ok"));
  const { submit } = form(onSignIn);
  submit();
  await waitFor(() => {
    expect(onSignIn).toHaveBeenCalledTimes(1);
  });
  await act(async () => {
    await new Promise((resolve) => setTimeout(resolve, 0));
  });
  expect(screen.queryByRole("alert")).toBeNull();
  expect(screen.getByRole("button", { name: "Signing in…" })).toBeDefined();
});

test("refused credentials mark both fields invalid", async () => {
  const { submit } = form(() => Promise.resolve<AuthResult>("invalid"));
  submit();
  expect((await screen.findByRole("alert")).textContent).toBe(
    "Wrong email or password.",
  );
  expect(invalidity()).toEqual(["true", "true"]);
});

test("a failed sign-in marks no field", async () => {
  const { submit } = form(() => Promise.resolve<AuthResult>("failed"));
  submit();
  expect(await screen.findByRole("alert")).toBeDefined();
  expect(invalidity()).toEqual([null, null]);
});

test("trying again clears the last problem while it is pending", async () => {
  const answers: Promise<AuthResult>[] = [
    Promise.resolve("invalid"),
    new Promise(() => undefined),
  ];
  const { submit } = form(() => answers.shift() ?? Promise.resolve("ok"));
  submit();
  expect(await screen.findByRole("alert")).toBeDefined();
  await waitFor(() => {
    expect(screen.getByRole("button", { name: "Sign in" })).toBeDefined();
  });
  submit();
  await waitFor(() => {
    expect(screen.queryByRole("alert")).toBeNull();
  });
  expect(invalidity()).toEqual([null, null]);
});
