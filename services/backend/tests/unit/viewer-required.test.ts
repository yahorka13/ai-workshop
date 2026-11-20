import { expect, test } from "bun:test";
import { GraphQLError } from "graphql";
import { viewerRequired } from "../../src/graphql/viewer-required";
import type { UserStats } from "../../src/dashboard";

const userStats: UserStats = {
  total: () => Promise.resolve(0),
  createdPerDay: () => Promise.resolve([]),
};
const base = { probe: () => Promise.resolve(true), userStats };
const demo = { id: "u1", name: "Demo User", email: "demo@example.com" };

test("a signed-in context gives its viewer", () => {
  expect(viewerRequired({ ...base, viewer: demo })).toEqual(demo);
});

test("a signed-out context is refused as UNAUTHENTICATED", () => {
  let thrown: unknown;
  try {
    viewerRequired({ ...base, viewer: null });
  } catch (error) {
    thrown = error;
  }
  expect(thrown).toBeInstanceOf(GraphQLError);
  expect(thrown).toMatchObject({
    message: "Sign in to see this.",
    extensions: { code: "UNAUTHENTICATED" },
  });
});
