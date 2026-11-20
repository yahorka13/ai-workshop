// Limits on an operation's shape, checked while the query is validated, so a
// refused query never runs: how deep its fields nest and how many fields it
// selects, each alias and each fragment spread counted. Introspection is exempt.
import {
  GraphQLError,
  Kind,
  type GraphQLFormattedError,
  type OperationDefinitionNode,
  type SelectionSetNode,
  type ValidationContext,
  type ValidationRule,
} from "graphql";

export const MAX_DEPTH = 8;
export const MAX_FIELDS = 100;

type Size = { depth: number; fields: number };

const CODE = "QUERY_TOO_COMPLEX";

const INTROSPECTION_ROOTS = new Set(["__schema", "__type"]);

// One measurement per operation, shared by both rules.
const measured = new WeakMap<OperationDefinitionNode, Size>();

/**
 * How deep the operation's fields nest and how many it selects. Each fragment
 * is measured once, relative to where it is spread, so fragments that spread
 * each other twice over cost linear time, not exponential.
 */
function sizeOf(
  context: ValidationContext,
  operation: OperationDefinitionNode,
): Size {
  const known = measured.get(operation);
  if (known !== undefined) return known;
  const fragments = new Map<string, Size>();
  const visiting = new Set<string>();
  // The size of a selection set whose own fields count as depth 1.
  const walk = (set: SelectionSetNode): Size => {
    const size: Size = { depth: 0, fields: 0 };
    const add = (inner: Size): void => {
      size.depth = Math.max(size.depth, inner.depth);
      size.fields += inner.fields;
    };
    for (const selection of set.selections) {
      if (selection.kind === Kind.FIELD) {
        // Only the root Query has these, so they are skipped wherever met.
        if (INTROSPECTION_ROOTS.has(selection.name.value)) continue;
        const inner =
          selection.selectionSet === undefined
            ? { depth: 0, fields: 0 }
            : walk(selection.selectionSet);
        add({ depth: inner.depth + 1, fields: inner.fields + 1 });
      } else if (selection.kind === Kind.INLINE_FRAGMENT) {
        add(walk(selection.selectionSet));
      } else {
        add(fragmentSize(selection.name.value));
      }
    }
    return size;
  };
  const fragmentSize = (name: string): Size => {
    const cached = fragments.get(name);
    if (cached !== undefined) return cached;
    const fragment = context.getFragment(name);
    // An unknown or cyclic fragment is another rule's error.
    if (fragment === null || fragment === undefined || visiting.has(name)) {
      return { depth: 0, fields: 0 };
    }
    visiting.add(name);
    const size = walk(fragment.selectionSet);
    visiting.delete(name);
    fragments.set(name, size);
    return size;
  };
  const size = walk(operation.selectionSet);
  measured.set(operation, size);
  return size;
}

function limit(
  max: number,
  of: (size: Size) => number,
  message: (value: number) => string,
): ValidationRule {
  return (context) => ({
    OperationDefinition(operation) {
      const value = of(sizeOf(context, operation));
      if (value <= max) return;
      context.reportError(
        new GraphQLError(message(value), {
          nodes: [operation],
          extensions: { code: CODE },
        }),
      );
    },
  });
}

/** Refuses an operation whose fields nest deeper than `max`. */
export function depthLimit(max: number): ValidationRule {
  return limit(
    max,
    (size) => size.depth,
    (depth) => `Query depth ${depth} exceeds the limit of ${max}.`,
  );
}

/** Refuses an operation that selects more than `max` fields. */
export function fieldLimit(max: number): ValidationRule {
  return limit(
    max,
    (size) => size.fields,
    (fields) => `Query selects ${fields} fields; the limit is ${max}.`,
  );
}

/** The API's limits, passed to Apollo as validation rules. */
export const queryLimits: ValidationRule[] = [
  depthLimit(MAX_DEPTH),
  fieldLimit(MAX_FIELDS),
];

/**
 * Apollo's formatError: Apollo answers every validation error with the code
 * GRAPHQL_VALIDATION_FAILED, keeping the rule's error as originalError; this
 * gives a limit's refusal its own code back.
 */
export function keepLimitCode(
  formatted: GraphQLFormattedError,
  error: unknown,
): GraphQLFormattedError {
  if (!(error instanceof GraphQLError)) return formatted;
  const original = error.originalError;
  if (!(original instanceof GraphQLError)) return formatted;
  if (original.extensions.code !== CODE) return formatted;
  return { ...formatted, extensions: { ...formatted.extensions, code: CODE } };
}
