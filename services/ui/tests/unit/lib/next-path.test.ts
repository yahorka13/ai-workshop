import { expect, test } from "bun:test";
import { safeNext } from "@/lib/next-path";

test.each([
  ["/no-such-page?x=1", "/no-such-page?x=1"],
  ["/", "/"],
  [null, "/"],
  ["", "/"],
  ["//evil.example", "/"],
  ["//evil.example/steal?x=1", "/"],
  // A path no browser can read as a URL.
  ["//", "/"],
  ["/\\evil.example", "/"],
  ["https://evil.example", "/"],
  ["no-slash", "/"],
  // Browsers drop tabs and newlines from a URL, so these mean //evil.example.
  ["/\t/evil.example", "/"],
  ["/\n/evil.example", "/"],
  ["/a/b?c=1#d", "/a/b?c=1#d"],
])("[auth-cea8c2] next=%p opens %p", (next, path) => {
  expect(safeNext(next)).toBe(path);
});
