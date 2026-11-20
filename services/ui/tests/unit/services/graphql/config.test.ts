import { expect, test } from "bun:test";
import { apiUrl } from "@/services/graphql/config";

test("[app-shell-c757ea] a bare http(s) origin is the API's origin", () => {
  expect(apiUrl({ VITE_API_URL: "http://127.0.0.1:11101" })).toBe(
    "http://127.0.0.1:11101",
  );
  expect(apiUrl({ VITE_API_URL: "https://api.example.test/" })).toBe(
    "https://api.example.test",
  );
});

test("[app-shell-c757ea] anything else leaves the API not configured", () => {
  for (const value of [
    undefined,
    "",
    42,
    "not a url",
    "ftp://x.test",
    "http://u:p@x.test",
    "http://x.test/path",
    "http://x.test/?q=1",
    "http://x.test/#top",
  ])
    expect(apiUrl({ VITE_API_URL: value })).toBeUndefined();
  expect(apiUrl({})).toBeUndefined();
});
