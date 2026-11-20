import { expect, test } from "bun:test";
import { viewerFromSession } from "../../src/viewer";

test("a session answer becomes the viewer", () => {
  expect(
    viewerFromSession({
      user: { id: "u1", name: "Demo User", email: "demo@example.com", x: 1 },
      session: {},
    }),
  ).toEqual({ id: "u1", name: "Demo User", email: "demo@example.com" });
});

test.each([null, undefined, {}, { user: { id: 1 } }])(
  "an answer that is not a session is no viewer: %p",
  (answer) => {
    expect(viewerFromSession(answer)).toBeNull();
  },
);
