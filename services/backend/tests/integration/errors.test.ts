import { expect, spyOn, test } from "bun:test";
import express from "express";
import { errorHandler } from "../../src/http/errors";
import { serving } from "../support/listen";

test("a thrown error answers a bare 500 and is logged", async () => {
  const log = spyOn(console, "error").mockImplementation(() => undefined);
  const app = express();
  app.get("/boom", () => {
    throw new Error("secret detail");
  });
  app.use(errorHandler);
  try {
    const { status, text } = await serving(app, async (base) => {
      const response = await fetch(`${base}/boom`);
      return { status: response.status, text: await response.text() };
    });
    expect(status).toBe(500);
    expect(JSON.parse(text)).toEqual({ error: "Internal error" });
    expect(text).not.toContain("secret detail");
    expect(log).toHaveBeenCalledTimes(1);
  } finally {
    log.mockRestore();
  }
});
