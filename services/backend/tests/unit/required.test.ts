import { expect, test } from "bun:test";
import { required } from "../../src/required";

test("required returns a present value, falsy ones included", () => {
  expect(required("id", "id")).toBe("id");
  expect(required(0, "count")).toBe(0);
  expect(required("", "name")).toBe("");
});

test.each([null, undefined])(
  "required throws naming what is missing on %p",
  (value) => {
    expect(() => required(value, "row")).toThrow(new Error("row is missing"));
  },
);
