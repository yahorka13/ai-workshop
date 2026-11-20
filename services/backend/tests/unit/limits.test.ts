import { expect, test } from "bun:test";
import {
  GraphQLError,
  getIntrospectionQuery,
  parse,
  validate,
  type ValidationRule,
} from "graphql";
import {
  MAX_DEPTH,
  MAX_FIELDS,
  depthLimit,
  fieldLimit,
  keepLimitCode,
  queryLimits,
} from "../../src/graphql/limits";
import { schema } from "../../src/graphql/schema";

function errors(
  query: string,
  rules: ValidationRule[],
): { message: string; extensions: unknown }[] {
  return validate(schema, parse(query), rules).map(
    ({ message, extensions }) => ({ message, extensions }),
  );
}

const tooComplex = (
  message: string,
): { message: string; extensions: { code: string } } => ({
  message,
  extensions: { code: "QUERY_TOO_COMPLEX" },
});

const deep = "{ dashboard { signUps { day } } }";

test("[contracts-6add5c] a selection one level past the depth limit is refused", () => {
  const refusal = [tooComplex("Query depth 3 exceeds the limit of 2.")];
  expect(errors(deep, [depthLimit(2)])).toEqual(refusal);
  expect(
    errors(
      "fragment F on Dashboard { signUps { day } } { dashboard { ...F } }",
      [depthLimit(2)],
    ),
  ).toEqual(refusal);
  expect(
    errors("{ dashboard { ... on Dashboard { signUps { day } } } }", [
      depthLimit(2),
    ]),
  ).toEqual(refusal);
});

test("[contracts-4f83fa] a selection at the depth limit passes", () => {
  expect(errors(deep, [depthLimit(3)])).toEqual([]);
});

const aliased = "{ a: health { ok } b: health { ok } c: health { ok } }";

test("[contracts-e79819] aliases past the field limit are refused", () => {
  expect(errors(aliased, [fieldLimit(4)])).toEqual([
    tooComplex("Query selects 6 fields; the limit is 4."),
  ]);
  expect(
    errors(
      "fragment H on Health { ok } { a: health { ...H } b: health { ...H } }",
      [fieldLimit(3)],
    ),
  ).toEqual([tooComplex("Query selects 4 fields; the limit is 3.")]);
});

test("[contracts-d1de56] a selection within the field limit passes", () => {
  expect(errors(aliased, [fieldLimit(6)])).toEqual([]);
});

test("[contracts-f0fd4e] introspection is exempt from both limits", () => {
  expect(errors(getIntrospectionQuery(), queryLimits)).toEqual([]);
  expect(
    errors(getIntrospectionQuery(), [depthLimit(1), fieldLimit(1)]),
  ).toEqual([]);
  expect(errors("{ __typename health { ok } }", [fieldLimit(2)])).toEqual([
    tooComplex("Query selects 3 fields; the limit is 2."),
  ]);
});

test("each operation of a document is measured alone", () => {
  expect(
    errors(
      "query A { health { ok } __typename } query B { viewer { id } __typename }",
      [fieldLimit(3), depthLimit(2)],
    ),
  ).toEqual([]);
});

test("an unknown or cyclic fragment is left to the other rules", () => {
  expect(
    errors("{ health { ...Missing } }", [depthLimit(2), fieldLimit(5)]),
  ).toEqual([]);
  expect(
    errors(
      "fragment A on Health { ok ...B } fragment B on Health { ok ...A } { health { ...A } }",
      [depthLimit(2), fieldLimit(5)],
    ),
  ).toEqual([]);
});

test("the API's limits are a depth of 8 and 100 fields", () => {
  expect(MAX_DEPTH).toBe(8);
  expect(MAX_FIELDS).toBe(100);
  expect(queryLimits).toHaveLength(2);
});

const validationFailed = {
  message: "m",
  extensions: { code: "GRAPHQL_VALIDATION_FAILED", http: 400 },
};

test("a limit's refusal keeps its code through Apollo's validation wrapper", () => {
  const limitError = new GraphQLError("m", {
    extensions: { code: "QUERY_TOO_COMPLEX" },
  });
  const wrapped = new GraphQLError("m", { originalError: limitError });
  expect(keepLimitCode(validationFailed, wrapped)).toEqual({
    message: "m",
    extensions: { code: "QUERY_TOO_COMPLEX", http: 400 },
  });
});

test("every other error is formatted as Apollo formats it", () => {
  const other = new GraphQLError("m", {
    originalError: new GraphQLError("m", { extensions: { code: "OTHER" } }),
  });
  for (const error of [
    new Error("m"),
    new GraphQLError("m"),
    new GraphQLError("m", { originalError: new Error("m") }),
    other,
  ]) {
    expect(keepLimitCode(validationFailed, error)).toBe(validationFailed);
  }
});

test("doubling fragments are measured in linear time and refused", () => {
  // Fragment F0 spreads F1 twice, F1 spreads F2 twice, ...: 2^30 health
  // selections in about 1 KB; measured naively it would take minutes.
  const levels = 30;
  const fragments = Array.from({ length: levels }, (_, i) =>
    i === levels - 1
      ? `fragment F${String(i)} on Query { health { ok } }`
      : `fragment F${String(i)} on Query { ...F${String(i + 1)} ...F${String(i + 1)} }`,
  ).join(" ");
  const started = performance.now();
  const refused = errors(`{ ...F0 } ${fragments}`, queryLimits);
  expect(performance.now() - started).toBeLessThan(500);
  expect(refused).toEqual([
    tooComplex(`Query selects ${String(2 ** 30)} fields; the limit is 100.`),
  ]);
});

test("a fragment spread deeper counts its depth from where it is spread", () => {
  expect(
    errors(
      "fragment S on Dashboard { signUps { day } } fragment D on Query { dashboard { ...S } } { ...D }",
      [depthLimit(2)],
    ),
  ).toEqual([tooComplex("Query depth 3 exceeds the limit of 2.")]);
});
