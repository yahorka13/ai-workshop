import { expect, test } from "bun:test";
import { dayLabel } from "@/lib/day-label";

test.each([
  ["2026-11-16", "Mon 16"],
  ["2026-11-01", "Sun 1"],
])("the day %p is labelled %p in UTC", (day, label) => {
  expect(dayLabel(day)).toBe(label);
});
