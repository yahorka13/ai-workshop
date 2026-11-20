import {
  cpSync,
  existsSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  rmSync,
  symlinkSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";

export const serviceRoot = resolve(import.meta.dir, "..");

// A scratch copy of the service's config and tooling with the given files.
export type Fixture = {
  root: string;
  run: (...args: string[]) => Bun.SyncSubprocess<"pipe", "pipe">;
  close: () => void;
};

export function fixture(files: Record<string, string>): Fixture {
  const root = mkdtempSync(join(tmpdir(), "service-gates-"));
  for (const name of [
    "package.json",
    "tsconfig.json",
    "eslint.config.mjs",
    ".prettierrc.json",
    ".prettierignore",
    "bunfig.toml",
    ".jscpd.json",
    ".dependency-cruiser.mjs",
  ]) {
    cpSync(join(serviceRoot, name), join(root, name));
  }
  if (existsSync(join(serviceRoot, "tooling"))) {
    // A fixture carries no src/, so tooling that imports from it stays out.
    cpSync(join(serviceRoot, "tooling"), join(root, "tooling"), {
      recursive: true,
      filter: (source) =>
        !source.endsWith(".ts") ||
        !/from "(\.\.\/)+src\//.test(readFileSync(source, "utf8")),
    });
  }
  symlinkSync(
    join(serviceRoot, "node_modules"),
    join(root, "node_modules"),
    "dir",
  );
  for (const [name, value] of Object.entries(files)) {
    mkdirSync(dirname(join(root, name)), { recursive: true });
    writeFileSync(join(root, name), value);
  }
  return {
    root,
    run: (...args: string[]) =>
      Bun.spawnSync([process.execPath, ...args], {
        cwd: root,
        env: process.env,
        stdout: "pipe",
        stderr: "pipe",
      }),
    close: () => rmSync(root, { recursive: true, force: true }),
  };
}
