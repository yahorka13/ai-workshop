import { expect, test } from "bun:test";
import { errorAnswer, errorHandler } from "../../src/http/errors";

test("a client error keeps its status without details", () => {
  expect(errorAnswer({ status: 413, message: "too large" })).toEqual({
    status: 413,
    body: { error: "Bad request" },
  });
});

test("any other error is a bare 500", () => {
  for (const error of [new Error("secret detail"), { status: 503 }, "text"])
    expect(errorAnswer(error)).toEqual({
      status: 500,
      body: { error: "Internal error" },
    });
});

test("the handler has the four parameters Express routes errors to", () => {
  expect(errorHandler.length).toBe(4);
});
