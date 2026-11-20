import { expect, test } from "bun:test";
import { cn } from "@/lib/utils";

test("cn joins classes and lets the later Tailwind class win", () => {
  expect(cn("p-2", false, "text-sm", "p-4")).toBe("text-sm p-4");
});
