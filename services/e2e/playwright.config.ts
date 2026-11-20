import { defineConfig } from "@playwright/test";

/* Runs in the e2e image (bin/e2e) against a running stack. E2E_BASE_URL is the
   app's URL and E2E_API_URL the API's, both as a browser on the host sees
   them; E2E_FORWARDS maps those ports to the stack's services inside the
   container (tooling/global-setup.ts). E2E_PROOF=1 takes a screenshot of every
   test for the PR, and E2E_VIDEO=1 a video too (bin/e2e --proof [--video]). */

const baseURL = process.env.E2E_BASE_URL;
if (baseURL === undefined || baseURL === "") {
  throw new Error(
    "E2E_BASE_URL is not set: run the suite with bin/e2e against a stack from bin/up",
  );
}
const proof = process.env.E2E_PROOF === "1";
const video = proof && process.env.E2E_VIDEO === "1";

export default defineConfig({
  testDir: "tests",
  globalSetup: "./tooling/global-setup.ts",
  timeout: 30_000,
  expect: { timeout: 10_000 },
  fullyParallel: true,
  forbidOnly: true,
  reporter: [
    ["list"],
    ["html", { open: "never", outputFolder: "playwright-report" }],
    ...(proof ? [["./tooling/proof-reporter.ts"] as const] : []),
  ],
  outputDir: "test-results",
  use: {
    baseURL,
    actionTimeout: 10_000,
    trace: "retain-on-failure",
    screenshot: proof ? "on" : "only-on-failure",
    video: video ? "on" : "off",
  },
  projects: [
    { name: "desktop", use: { viewport: { width: 1440, height: 900 } } },
  ],
});
