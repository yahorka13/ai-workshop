// How the HTTP layer answers an error: a client error keeps its 4xx status,
// anything else is a 500 that reveals nothing.
import type { ErrorRequestHandler } from "express";
import { z } from "zod";

export type ErrorAnswer = { status: number; body: { error: string } };

// Express marks a body it could not parse, or one too large, with a 4xx.
const ClientError = z.object({ status: z.number().int().min(400).max(499) });

/** The status and body that answer an error. */
export function errorAnswer(error: unknown): ErrorAnswer {
  const client = ClientError.safeParse(error);
  return client.success
    ? { status: client.data.status, body: { error: "Bad request" } }
    : { status: 500, body: { error: "Internal error" } };
}

// Express 5 routes errors only to a function of four parameters, by its
// `length`; the rest tuple has none, so the length is set to the four it passes.
const handler: ErrorRequestHandler = (...[error, , response]) => {
  const answer = errorAnswer(error);
  if (answer.status === 500) console.error(error);
  response.status(answer.status).json(answer.body);
};

export const errorHandler: ErrorRequestHandler = Object.defineProperty(
  handler,
  "length",
  { value: 4 },
);
