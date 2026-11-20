// The backend's GraphQL contract as committed: the Pothos schema of
// src/graphql/schema.ts, rendered with its notice and sorted, so generation
// runs offline and reproducibly.
import {
  lexicographicSortSchema,
  printSchema,
  validateSchema,
  type GraphQLSchema,
} from "graphql";
import { commentNotice } from "./files";

// Pothos rejects a field whose type it never saw while it builds the schema,
// before graphql-js validates anything; either way the error names the file.
export function buildContract(build: () => GraphQLSchema): GraphQLSchema {
  try {
    return build();
  } catch (error) {
    throw new Error(
      `schema.graphql: invalid GraphQL schema:\n- ${error instanceof Error ? error.message : String(error)}`,
      { cause: error },
    );
  }
}

// The committed `contracts/schema.graphql`: the notice, then the sorted SDL.
export function renderSchema(schema: GraphQLSchema): string {
  const errors = validateSchema(schema);
  if (errors.length > 0) {
    throw new Error(
      `schema.graphql: invalid GraphQL schema:\n${errors
        .map((error) => `- ${error.message}`)
        .join("\n")}`,
    );
  }
  return `${commentNotice("#")}\n${printSchema(lexicographicSortSchema(schema))}\n`;
}
