import { expect, test } from "bun:test";
import { act } from "@testing-library/react";

test("main.tsx mounts the app into #root", async () => {
  const root = document.createElement("div");
  root.id = "root";
  document.body.append(root);
  await act(async () => {
    await import("@/main");
  });
  expect(root.querySelector("main")?.textContent).toContain("Factory");
  root.remove();
});
