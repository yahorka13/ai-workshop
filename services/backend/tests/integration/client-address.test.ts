import { expect, test } from "bun:test";
import express from "express";
import { clientAddress } from "../../src/auth";
import { serving } from "../support/listen";

test("the client address better-auth reads is the request's, whatever the client claimed", async () => {
  const app = express();
  // Behind a proxy, Express reads the address from x-forwarded-for.
  app.set("trust proxy", true);
  app.get("/", clientAddress, (request, response) => {
    response.json(request.headers["x-factory-client-address"]);
  });
  const seen: unknown = await serving(app, async (base) => {
    const response = await fetch(`${base}/`, {
      headers: {
        "x-forwarded-for": "203.0.113.7",
        "x-factory-client-address": "198.51.100.1",
      },
    });
    const body: unknown = await response.json();
    return body;
  });
  expect(seen).toBe("203.0.113.7");
});
