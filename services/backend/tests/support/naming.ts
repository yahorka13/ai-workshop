// The naming rule (AGENTS.md): a query is named after the resource it returns,
// with no verb, and a mutation creates, updates or deletes. A field that
// cannot follow it is listed here with its reason.
import {
  getNamedType,
  getNullableType,
  isListType,
  type GraphQLOutputType,
  type GraphQLSchema,
} from "graphql";

const NAMING_EXCEPTIONS: Record<string, string> = {};

// `Contact!` names `contact`, `[Contact!]!` names `contacts`.
function resourceName(type: GraphQLOutputType): string {
  const named = getNamedType(type).name;
  const name = named.charAt(0).toLowerCase() + named.slice(1);
  return isListType(getNullableType(type)) ? `${name}s` : name;
}

/** Every root field that breaks the rule, with what it should be. */
export function namingProblems(schema: GraphQLSchema): string[] {
  const listed = (name: string): boolean => name in NAMING_EXCEPTIONS;
  const queries = Object.values(schema.getQueryType()?.getFields() ?? {})
    .filter((field) => !listed(field.name))
    .filter((field) => field.name !== resourceName(field.type))
    .map((field) => `query ${field.name}: name it ${resourceName(field.type)}`);
  const mutations = Object.values(schema.getMutationType()?.getFields() ?? {})
    .filter((field) => !listed(field.name))
    .filter((field) => !/^(create|update|delete)[A-Z]/.test(field.name))
    .map(
      (field) =>
        `mutation ${field.name}: start it with create, update or delete`,
    );
  return [...queries, ...mutations];
}
