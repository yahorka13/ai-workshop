import { expect, test } from "bun:test";
import {
  mkdirSync,
  mkdtempSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import { join } from "node:path";
import { serviceRoot } from "../fixtures";
import { localeKeys, unusedKeys } from "../support/i18n-keys";

function typecheck(source: string): Bun.SyncSubprocess<"pipe", "pipe"> {
  mkdirSync(join(serviceRoot, "tmp"), { recursive: true });
  const dir = mkdtempSync(join(serviceRoot, "tmp", "i18n-probe-"));
  try {
    writeFileSync(join(dir, "probe.ts"), source);
    writeFileSync(
      join(dir, "tsconfig.json"),
      JSON.stringify({
        extends: "../../tsconfig.json",
        include: ["../../src/**/*", "probe.ts"],
      }),
    );
    return Bun.spawnSync(
      [process.execPath, "--bun", "tsc", "--noEmit", "-p", dir],
      { cwd: serviceRoot, stdout: "pipe", stderr: "pipe" },
    );
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}

// Each test runs a full tsc over src/, beside the other gates in bin/check.
const TYPECHECK_TIMEOUT = 120_000;

test(
  "[service-checks-0e451e] an unknown key fails the typecheck and is named",
  () => {
    const run = typecheck(
      'import { i18n } from "@/i18n";\nexport const text = i18n.t("no.such.key");\n',
    );
    expect(run.exitCode).not.toBe(0);
    expect(run.stdout.toString()).toContain("probe.ts");
    expect(run.stdout.toString()).toContain("no.such.key");
  },
  TYPECHECK_TIMEOUT,
);

test(
  "[service-checks-0e451e] a key the locale defines typechecks",
  () => {
    const run = typecheck(
      'import { i18n } from "@/i18n";\nexport const text = i18n.t("app.name");\n',
    );
    expect(run.stdout.toString()).toBe("");
    expect(run.exitCode).toBe(0);
  },
  TYPECHECK_TIMEOUT,
);

const locale: unknown = JSON.parse(
  readFileSync(join(serviceRoot, "src/i18n/locales/en/common.json"), "utf8"),
);
const sources = [
  ...new Bun.Glob("src/**/*.{ts,tsx}").scanSync({ cwd: serviceRoot }),
].map((path) => readFileSync(join(serviceRoot, path), "utf8"));

test("[service-checks-6a91cd] every key in the English locale is used", () => {
  expect(unusedKeys(localeKeys(locale), sources)).toEqual([]);
});

test("[service-checks-6a91cd] an unused key is named", () => {
  const keys = localeKeys({ app: { name: "x", unused: "y" } });
  expect(keys).toEqual(["app.name", "app.unused"]);
  expect(unusedKeys(keys, ['t("app.name")'])).toEqual(["app.unused"]);
  expect(unusedKeys(["a.b"], ["t('a.b')", "t(`c`)"])).toEqual([]);
});
