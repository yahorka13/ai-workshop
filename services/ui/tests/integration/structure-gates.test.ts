import { expect, test } from "bun:test";
import {
  cpSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  rmSync,
  symlinkSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { z } from "zod";
import { fixture, serviceRoot } from "../fixtures";

// One block of more than 50 tokens over 7 lines, written to two files so the
// test itself holds no clone.
const block = [
  "export function total(items: { price: number; count: number }[]): number {",
  "  let sum = 0;",
  "  for (const item of items) {",
  "    if (item.count > 0) sum += item.price * item.count;",
  "    else sum -= item.price;",
  "  }",
  "  return Math.round(sum * 100) / 100 + items.length * 0;",
  "}",
  "",
].join("\n");

// The marks are built in parts so this file is not counted as holding one.
const mark = (edge: string): string => ["// jscpd:ignore", edge].join("-");
const marked = `${mark("start")} test\n${block}${mark("end")}\n`;

function duplicates(files: Record<string, string>): {
  exitCode: number;
  output: string;
} {
  const project = fixture(files);
  try {
    const run = project.run("run", "duplicates");
    return {
      exitCode: run.exitCode,
      output: run.stdout.toString() + run.stderr.toString(),
    };
  } finally {
    project.close();
  }
}

test("[service-checks-7cc7ba] a copied block fails naming both copies", () => {
  const { exitCode, output } = duplicates({
    "src/a.ts": block,
    "tests/b.ts": block,
  });
  expect(exitCode).not.toBe(0);
  expect(output).toMatch(/src\/a\.ts \[\d+:\d+ - \d+:\d+\]/);
  expect(output).toMatch(/tests\/b\.ts \[\d+:\d+ - \d+:\d+\]/);
  expect(output).toContain("extract the shared code");
}, 30000);

test("[service-checks-7cc7ba] a copy across .ts and .tsx files fails", () => {
  const { exitCode, output } = duplicates({
    "src/a.ts": block,
    "tests/b.tsx": block,
  });
  expect(exitCode).not.toBe(0);
  expect(output).toMatch(/tests\/b\.tsx \[\d+:\d+ - \d+:\d+\]/);
}, 30000);

test("[service-checks-7cc7ba] a copy inside src/contracts/ fails", () => {
  const { exitCode, output } = duplicates({
    "src/contracts/a.ts": block,
    "src/contracts/b.ts": block,
    "tests/x.ts": "export const x = 1;\n",
  });
  expect(exitCode).not.toBe(0);
  expect(output).toMatch(/src\/contracts\/b\.ts \[\d+:\d+ - \d+:\d+\]/);
}, 30000);

test("[service-checks-7cc7ba] shared import lines alone are not a clone", () => {
  const imports = [
    'import { readFileSync, writeFileSync } from "node:fs";',
    'import { dirname, join, resolve } from "node:path";',
    'import { tmpdir } from "node:os";',
    'import { expect, spyOn, test } from "bun:test";',
    'import { z } from "zod";',
    "",
  ].join("\n");
  const { exitCode } = duplicates({
    "src/a.ts": `${imports}export const a = 1;\n`,
    "tests/b.ts": `${imports}export const b = 2;\n`,
  });
  expect(exitCode).toBe(0);
}, 30000);

test("[service-checks-63937c] generated code is not compared", () => {
  // Every scanned folder must exist, as it does in a service.
  const tests = { "tests/x.ts": "export const x = 1;\n" };
  for (const generated of ["src/generated/b.ts", "contracts/b.ts"]) {
    const files = { ...tests, "src/a.ts": block, [generated]: block };
    expect(duplicates(files).exitCode).toBe(0);
  }
}, 30000);

test("[service-checks-b4b48e] a marked clone passes", () => {
  expect(duplicates({ "src/a.ts": block, "tests/b.ts": marked }).exitCode).toBe(
    0,
  );
}, 30000);

const Manifest = z.object({
  scripts: z.object({ unused: z.string() }).loose(),
  devDependencies: z.record(z.string(), z.string()),
});

// A project of only the given files, the service's unused-code config and its
// unused script, so nothing else of the service is reported.
function unused(
  files: Record<string, string>,
  dependencies: Record<string, string> = {},
): { exitCode: number; output: string } {
  const service = Manifest.parse(
    JSON.parse(readFileSync(join(serviceRoot, "package.json"), "utf8")),
  );
  const manifest = {
    name: "probe",
    private: true,
    type: "module",
    scripts: { start: "bun src/index.ts", unused: service.scripts.unused },
    dependencies,
    // The tools Knip and the tsconfig need, at the service's versions.
    devDependencies: Object.fromEntries(
      Object.entries(service.devDependencies).filter(([name]) =>
        ["knip", "typescript", "@types/bun", "vite"].includes(name),
      ),
    ),
  };
  const root = mkdtempSync(join(tmpdir(), "unused-gate-"));
  try {
    for (const name of ["tsconfig.json", "knip.config.ts"]) {
      cpSync(join(serviceRoot, name), join(root, name));
    }
    symlinkSync(join(serviceRoot, "node_modules"), join(root, "node_modules"));
    const all = {
      "package.json": JSON.stringify(manifest, null, 2),
      "src/index.ts": 'import { used } from "./a";\n\nconsole.log(used());\n',
      ...files,
    };
    for (const [name, value] of Object.entries(all)) {
      mkdirSync(dirname(join(root, name)), { recursive: true });
      writeFileSync(join(root, name), value);
    }
    const run = Bun.spawnSync([process.execPath, "run", "unused"], {
      cwd: root,
      stdout: "pipe",
      stderr: "pipe",
    });
    return {
      exitCode: run.exitCode,
      output: run.stdout.toString() + run.stderr.toString(),
    };
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
}

const exportsBoth =
  "export const used = (): number => 1;\nexport const unused = (): number => 2;\n";

test("[service-checks-d169b4] an unused export fails", () => {
  const { exitCode, output } = unused({ "src/a.ts": exportsBoth });
  expect(exitCode).not.toBe(0);
  expect(output).toMatch(/unused\s+src\/a\.ts:2/);
  expect(output).toContain("delete it or stop exporting it");
}, 30000);

test("[service-checks-976eee] an unused file fails", () => {
  const { exitCode, output } = unused({
    "src/a.ts": "export const used = (): number => 1;\n",
    "src/orphan.ts": "export const orphan = 1;\n",
  });
  expect(exitCode).not.toBe(0);
  expect(output).toContain("src/orphan.ts");
}, 30000);

test("[service-checks-976eee] an unused tooling module fails", () => {
  const { exitCode, output } = unused({
    "src/a.ts": "export const used = (): number => 1;\n",
    "tooling/orphan.ts": "export const orphan = 1;\n",
  });
  expect(exitCode).not.toBe(0);
  expect(output).toContain("tooling/orphan.ts");
}, 30000);

test("[service-checks-52637d] an unused dependency fails", () => {
  const { exitCode, output } = unused(
    { "src/a.ts": "export const used = (): number => 1;\n" },
    { "left-pad": "1.3.0" },
  );
  expect(exitCode).not.toBe(0);
  expect(output).toMatch(/left-pad\s+package\.json:\d+/);
}, 30000);

test("[service-checks-3f992d] a marked export passes", () => {
  const { exitCode, output } = unused({
    "src/a.ts": exportsBoth.replace(
      "export const unused",
      `/** ${["@knip", "ignore"].join("")} test */\nexport const unused`,
    ),
  });
  expect(output).not.toContain("src/a.ts");
  expect(exitCode).toBe(0);
}, 30000);

function imports(files: Record<string, string>): {
  exitCode: number;
  output: string;
} {
  // Every cruised folder must exist, as it does in a service.
  const project = fixture({ "tests/x.ts": "export const x = 1;\n", ...files });
  try {
    const run = project.run("run", "imports");
    return {
      exitCode: run.exitCode,
      output: run.stdout.toString() + run.stderr.toString(),
    };
  } finally {
    project.close();
  }
}

test("[service-checks-21ca49] a cycle fails", () => {
  const two = imports({
    "src/a.ts":
      'import { b } from "./b";\nexport const a = (): number => b();\n',
    "src/b.ts":
      'import { a } from "./a";\nexport const b = (): number => a();\n',
  });
  expect(two.exitCode).not.toBe(0);
  expect(two.output).toContain("no-circular");
  expect(two.output).toContain("src/a.ts");
  expect(two.output).toContain("src/b.ts");
  expect(two.output).toContain("move the shared part");
  const three = imports({
    "src/a.ts":
      'import { b } from "./b";\nexport const a = (): number => b();\n',
    "src/b.ts": 'import type { C } from "./c";\nexport const b = (): C => 1;\n',
    "src/c.ts":
      'import type { a } from "./a";\nexport type C = ReturnType<typeof a>;\n',
  });
  expect(three.exitCode).not.toBe(0);
  expect(three.output).toContain("src/c.ts");
}, 30000);

test("[service-checks-6bfd61] a component importing a service fails", () => {
  const { exitCode, output } = imports({
    "src/services/graphql/client.ts": "export const client = 1;\n",
    "src/components/X.tsx":
      'import { client } from "@/services/graphql/client";\nexport const X = client;\n',
  });
  expect(exitCode).not.toBe(0);
  expect(output).toContain("components-not-to-services");
  expect(output).toContain("src/components/X.tsx");
  expect(output).toContain("src/services/graphql/client.ts");
  expect(output).toContain("through a hook");
}, 30000);

test("[service-checks-9ff7b9] stories are exempt from layer rules", () => {
  const { exitCode, output } = imports({
    "src/services/graphql/client.ts": "export const client = 1;\n",
    "src/components/X.stories.tsx":
      'import { client } from "@/services/graphql/client";\nexport const X = client;\n',
  });
  expect(output).toMatch(/[1-9]\d* modules/);
  expect(exitCode).toBe(0);
}, 30000);

test("a story in a cycle with its component still fails", () => {
  const { exitCode, output } = imports({
    "src/components/X.tsx":
      'import { story } from "./X.stories";\nexport const X = story;\n',
    "src/components/X.stories.tsx":
      'import { X } from "./X";\nexport const story = (): unknown => X;\n',
  });
  expect(exitCode).not.toBe(0);
  expect(output).toContain("no-circular");
}, 30000);
