import { afterEach, expect, test } from "bun:test";
import {
  cpSync,
  existsSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import { join } from "node:path";
import { fixture, serviceRoot, type Fixture } from "../fixtures";

let project: Fixture | undefined;

afterEach(() => {
  project?.close();
  project = undefined;
});

// A scratch copy of the service with its source, tooling and contracts.
function service(): Fixture {
  const copy = fixture({});
  for (const path of ["src", "tooling", "contracts"])
    cpSync(join(serviceRoot, path), join(copy.root, path), { recursive: true });
  project = copy;
  return copy;
}

function contracts(copy: Fixture, command: string): [number, string] {
  const run = copy.run("tooling/contracts.ts", command);
  return [run.exitCode, run.stdout.toString() + run.stderr.toString()];
}

const sdl = (copy: Fixture): string =>
  join(copy.root, "contracts/schema.graphql");

test("[contracts-d364e3] a clean checkout's contracts are current", () => {
  const copy = service();
  const [code, output] = contracts(copy, "check");
  expect(output).toContain("contracts are current");
  expect(code).toBe(0);
  const text = readFileSync(sdl(copy), "utf8");
  expect(text).toContain("  health: Health!\n");
  expect(text.indexOf("type Health")).toBeLessThan(text.indexOf("type Query"));
});

test("[contracts-ed0454] the committed SDL starts with the generated notice", () => {
  const text = readFileSync(
    join(serviceRoot, "contracts/schema.graphql"),
    "utf8",
  );
  expect(text.split("\n").slice(0, 2)).toEqual([
    "# Generated file: do not edit it by hand.",
    "# Change its source and run bin/contracts generate.",
  ]);
});

test("[contracts-a3b248] [contracts-1df7a5] a field added without regenerating fails until generated", () => {
  const copy = service();
  const resource = join(copy.root, "src/graphql/resources/health.ts");
  writeFileSync(
    resource,
    readFileSync(resource, "utf8").replace(
      'ok: t.exposeBoolean("ok", { description: "True while it can serve." }),',
      'ok: t.exposeBoolean("ok", { description: "True while it can serve." }),\n    checkedAt: t.string({ resolve: () => "now" }),',
    ),
  );
  const [stale, output] = contracts(copy, "check");
  expect(stale).toBe(1);
  expect(output).toContain("changed: contracts/schema.graphql");
  expect(output).toContain("bin/contracts generate");
  const [generated, said] = contracts(copy, "generate");
  expect(generated).toBe(0);
  expect(said).toContain("generated: contracts");
  expect(readFileSync(sdl(copy), "utf8")).toContain("checkedAt: String!");
  expect(contracts(copy, "check")[0]).toBe(0);
});

test("[contracts-5233fe] a hand edit, CRLF or a missing final newline fails", () => {
  const copy = service();
  const original = readFileSync(sdl(copy), "utf8");
  for (const edited of [
    original.replace("health: Health!", "health: Health"),
    original.replaceAll("\n", "\r\n"),
    original.trimEnd(),
  ]) {
    writeFileSync(sdl(copy), edited);
    const [code, output] = contracts(copy, "check");
    expect(code).toBe(1);
    expect(output).toContain("changed: contracts/schema.graphql");
  }
  expect(contracts(copy, "generate")[0]).toBe(0);
  expect(readFileSync(sdl(copy), "utf8")).toBe(original);
});

test("a stray file fails as not generated, and generate removes it", () => {
  const copy = service();
  writeFileSync(join(copy.root, "contracts/notes.md"), "mine\n");
  const [code, output] = contracts(copy, "check");
  expect(code).toBe(1);
  expect(output).toContain("not generated: contracts/notes.md");
  expect(contracts(copy, "generate")[0]).toBe(0);
  expect(existsSync(join(copy.root, "contracts/notes.md"))).toBe(false);
});

test("a missing contracts folder fails, and generate recreates it", () => {
  const copy = service();
  rmSync(join(copy.root, "contracts"), { recursive: true });
  const [code, output] = contracts(copy, "check");
  expect(code).toBe(1);
  expect(output).toContain("missing: contracts/schema.graphql");
  expect(contracts(copy, "generate")[0]).toBe(0);
  expect(existsSync(sdl(copy))).toBe(true);
});

test("a schema that does not build fails generation and keeps the committed file", () => {
  const copy = service();
  const before = readFileSync(sdl(copy), "utf8");
  writeFileSync(
    join(copy.root, "src/graphql/schema.ts"),
    'import { GraphQLObjectType, GraphQLSchema } from "graphql";\nexport const schema = new GraphQLSchema({ query: new GraphQLObjectType({ name: "Query", fields: { __bad: { type: new GraphQLObjectType({ name: "Empty", fields: {} }) } } }) });\n',
  );
  const [code, output] = contracts(copy, "generate");
  expect(code).toBe(1);
  expect(output).toContain("schema.graphql: invalid GraphQL schema");
  expect(readFileSync(sdl(copy), "utf8")).toBe(before);
});

test("usage: --help exits 0, anything else exits 2", () => {
  const copy = service();
  const [help, usage] = contracts(copy, "--help");
  expect(help).toBe(0);
  expect(usage).toContain("Usage: bun tooling/contracts.ts <generate|check>");
  expect(contracts(copy, "publish")[0]).toBe(2);
  const none = copy.run("tooling/contracts.ts");
  expect(none.exitCode).toBe(2);
});
