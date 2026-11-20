import { expect, test } from "bun:test";
import { readFileSync, readdirSync, rmSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { contractSchemaPath } from "../../tooling/contracts-render";
import { fixture, serviceRoot, type Fixture } from "../fixtures";

// The backend's contract as bin/check mounts it.
const schema = readFileSync(contractSchemaPath(process.env), "utf8");
const operation = "src/services/graphql/health.ts";
const generated = "src/services/graphql/generated";

type ContractsRun = { exitCode: number; output: string };

// A scratch copy of the service with its operation, the generator and a
// CONTRACTS_DIR holding the backend's schema, and no generated output.
function project(): Fixture & {
  contracts: (...args: string[]) => ContractsRun;
} {
  const service = fixture({
    [operation]: readFileSync(join(serviceRoot, operation), "utf8"),
    "contracts/backend/schema.graphql": schema,
  });
  const env = {
    ...process.env,
    CONTRACTS_DIR: join(service.root, "contracts"),
  };
  return {
    ...service,
    contracts: (...args: string[]) => {
      const run = Bun.spawnSync(
        [process.execPath, "tooling/contracts.ts", ...args],
        { cwd: service.root, env, stdout: "pipe", stderr: "pipe" },
      );
      return {
        exitCode: run.exitCode,
        output: `${run.stdout.toString()}${run.stderr.toString()}`,
      };
    },
  };
}

test("generated documents pass the check, and carry the notice", () => {
  const service = project();
  try {
    expect(service.contracts("generate").exitCode).toBe(0);
    const files = readdirSync(join(service.root, generated));
    expect(files.sort()).toEqual(["gql.ts", "graphql.ts", "index.ts"]);
    for (const file of files)
      expect(
        readFileSync(join(service.root, generated, file), "utf8"),
      ).toStartWith("// Generated file: do not edit it by hand.\n");
    const check = service.contracts("check");
    expect(check.output).toContain("contracts are current");
    expect(check.exitCode).toBe(0);
  } finally {
    service.close();
  }
}, 30000);

test("[contracts-de85d3] a changed backend contract fails the check", () => {
  const service = project();
  try {
    expect(service.contracts("generate").exitCode).toBe(0);
    writeFileSync(
      join(service.root, "contracts/backend/schema.graphql"),
      schema.replace("ok: Boolean!", "ok: Boolean!\n  since: String"),
    );
    writeFileSync(
      join(service.root, operation),
      readFileSync(join(service.root, operation), "utf8").replace(
        "      ok\n",
        "      ok\n      since\n",
      ),
    );
    const check = service.contracts("check");
    expect(check.exitCode).not.toBe(0);
    expect(check.output).toContain(`changed: ${generated}/graphql.ts`);
  } finally {
    service.close();
  }
}, 30000);

test("[contracts-b276f4] a hand-edited or extra generated file fails", () => {
  const service = project();
  try {
    expect(service.contracts("generate").exitCode).toBe(0);
    const file = join(service.root, generated, "graphql.ts");
    writeFileSync(file, `${readFileSync(file, "utf8")}// edited\n`);
    writeFileSync(join(service.root, generated, "extra.ts"), "export {};\n");
    const check = service.contracts("check");
    expect(check.exitCode).not.toBe(0);
    expect(check.output).toContain(`changed: ${generated}/graphql.ts`);
    expect(check.output).toContain(`not generated: ${generated}/extra.ts`);
    rmSync(join(service.root, generated, "index.ts"));
    expect(service.contracts("check").output).toContain(
      `missing: ${generated}/index.ts`,
    );
  } finally {
    service.close();
  }
}, 30000);

test("[contracts-5a11b7] an operation selecting an unknown field fails generation", () => {
  const service = project();
  try {
    expect(service.contracts("generate").exitCode).toBe(0);
    const before = readFileSync(join(service.root, generated, "graphql.ts"));
    writeFileSync(
      join(service.root, operation),
      readFileSync(join(service.root, operation), "utf8").replace(
        "      ok\n",
        "      ok\n      noSuchField\n",
      ),
    );
    for (const command of ["check", "generate"]) {
      const run = service.contracts(command);
      expect(run.exitCode).not.toBe(0);
      expect(run.output).toContain("noSuchField");
    }
    expect(
      readFileSync(join(service.root, generated, "graphql.ts")).equals(before),
    ).toBe(true);
  } finally {
    service.close();
  }
}, 30000);

test("a missing backend contract fails, naming its path", () => {
  const service = project();
  try {
    rmSync(join(service.root, "contracts"), { recursive: true });
    const run = service.contracts("check");
    expect(run.exitCode).not.toBe(0);
    expect(run.output).toContain("contracts/backend/schema.graphql not found");
  } finally {
    service.close();
  }
}, 30000);

test("usage: --help prints it, a bad command exits 2", () => {
  const service = project();
  try {
    const help = service.contracts("--help");
    expect(help.exitCode).toBe(0);
    expect(help.output).toContain("Usage: bun tooling/contracts.ts");
    expect(service.contracts("nope").exitCode).toBe(2);
    expect(service.contracts("check", "extra").exitCode).toBe(2);
  } finally {
    service.close();
  }
}, 30000);
