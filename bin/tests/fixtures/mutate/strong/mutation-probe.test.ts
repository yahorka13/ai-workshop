import { expect, test } from "bun:test";
import { check, isAdult, ProbeError, reason } from "../../src/mutation-probe";

test("probe: adulthood starts at 18", () => {
  expect(isAdult(17)).toBe(false);
  expect(isAdult(18)).toBe(true);
  expect(isAdult(30)).toBe(true);
});

test("probe: the reason a client receives", () => {
  expect(reason()).toBe("probe reason");
});

test("probe: a negative age throws", () => {
  expect(() => check(-1)).toThrow(ProbeError);
  expect(() => check(0)).not.toThrow();
});
