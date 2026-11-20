import { afterEach, expect, spyOn, test } from "bun:test";
import { signIn, signOut } from "@/services/auth";
import { at } from "../../support/defined";

const fetchSpy = spyOn(globalThis, "fetch");
afterEach(() => {
  fetchSpy.mockReset();
});

function sent(): { url: unknown; init: RequestInit | undefined } {
  const call = at(fetchSpy.mock.calls, 0, "fetch calls");
  return { url: call[0], init: call[1] };
}

test("signIn posts the credentials with the session cookie and reads ok", async () => {
  fetchSpy.mockResolvedValue(Response.json({}, { status: 200 }));
  expect(await signIn("http://api", "demo@example.com", "password")).toBe("ok");
  const { url, init } = sent();
  expect(url).toBe("http://api/api/auth/sign-in/email");
  expect(init?.method).toBe("POST");
  expect(init?.credentials).toBe("include");
  expect(init?.headers).toEqual({ "content-type": "application/json" });
  const body = typeof init?.body === "string" ? init.body : "";
  expect(JSON.parse(body)).toEqual({
    email: "demo@example.com",
    password: "password",
  });
});

test.each([
  [401, "invalid"],
  [500, "failed"],
  [429, "failed"],
] as const)("a sign-in answered %p is %p", async (status, result) => {
  fetchSpy.mockResolvedValue(Response.json({}, { status }));
  expect(await signIn("http://api", "a@b.c", "x")).toBe(result);
});

test("a sign-in that gets no answer failed", async () => {
  fetchSpy.mockRejectedValue(new TypeError("Failed to fetch"));
  expect(await signIn("http://api", "a@b.c", "x")).toBe("failed");
});

test("signOut posts with the session cookie and reads ok or failed", async () => {
  fetchSpy.mockResolvedValueOnce(Response.json({}, { status: 200 }));
  expect(await signOut("http://api")).toBe("ok");
  const { url, init } = sent();
  expect(url).toBe("http://api/api/auth/sign-out");
  expect(init?.method).toBe("POST");
  expect(init?.credentials).toBe("include");
  fetchSpy.mockResolvedValueOnce(Response.json({}, { status: 500 }));
  expect(await signOut("http://api")).toBe("failed");
  fetchSpy.mockRejectedValueOnce(new TypeError("Failed to fetch"));
  expect(await signOut("http://api")).toBe("failed");
});
