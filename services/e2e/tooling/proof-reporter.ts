import { copyFileSync, mkdirSync, rmSync } from "node:fs";
import { extname, join } from "node:path";
import type { Reporter, TestCase, TestResult } from "@playwright/test/reporter";

/* With E2E_PROOF=1, copies each passing test's screenshot to proof/, and its
   video too with E2E_VIDEO=1, named after the test title, scenario IDs first:
   "[app-shell-c88136] an unknown path shows not found" becomes
   proof/app-shell-c88136-an-unknown-path-shows-not-found.png (and .webm).
   bin/e2e --proof moves them into the change; bin/proof-markdown captions them
   from the scenario the name starts with. */

const outputDir = "proof";
const kinds = new Set(
  process.env.E2E_VIDEO === "1" ? ["screenshot", "video"] : ["screenshot"],
);

export function proofName(title: string): string {
  return title
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 100)
    .replace(/-+$/, "");
}

export default class ProofReporter implements Reporter {
  private readonly copies: { from: string; to: string }[] = [];

  onBegin(): void {
    rmSync(outputDir, { recursive: true, force: true });
    mkdirSync(outputDir, { recursive: true });
  }

  onTestEnd(test: TestCase, result: TestResult): void {
    if (result.status !== "passed") return;
    const name = proofName(test.title);
    for (const attachment of result.attachments) {
      if (attachment.path === undefined || attachment.path === "") continue;
      if (!kinds.has(attachment.name)) continue;
      this.copies.push({
        from: attachment.path,
        to: join(outputDir, name + extname(attachment.path)),
      });
    }
  }

  onEnd(): void {
    for (const { from, to } of this.copies) copyFileSync(from, to);
  }
}
