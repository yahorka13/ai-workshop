// The UI calls the API from its own origin, so the API answers CORS for exactly
// that origin, with credentials. Any other origin gets no CORS header and its
// browser withholds the response.
import type { RequestHandler } from "express";

export function cors(appUrl: string): RequestHandler {
  return (request, response, next) => {
    response.vary("Origin");
    if (request.headers.origin !== appUrl) {
      next();
      return;
    }
    response.set({
      "Access-Control-Allow-Origin": appUrl,
      "Access-Control-Allow-Credentials": "true",
    });
    if (request.method !== "OPTIONS") {
      next();
      return;
    }
    response.set({
      "Access-Control-Allow-Methods": "GET, POST",
      "Access-Control-Allow-Headers": "Content-Type",
      "Access-Control-Max-Age": "600",
    });
    response.status(204).end();
  };
}
