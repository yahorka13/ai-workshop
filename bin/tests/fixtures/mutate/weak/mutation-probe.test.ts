import { expect, test } from "bun:test";
import { check, isAdult, ProbeError, reason } from "../../src/mutation-probe";

test("probe: an adult", () => {
  expect(isAdult(30)).toBe(true);
});

test("probe: a reason is text", () => {
  expect(typeof reason()).toBe("string");
});

test("probe: a negative age throws", () => {
  expect(() => check(-1)).toThrow(ProbeError);
  expect(() => check(0)).not.toThrow();
});
