// The GraphQL schema: every resource module registers its types on the
// builder when imported, so each one is imported here.
import type { GraphQLSchema } from "graphql";
import { builder } from "./builder";
import "./resources/dashboard";
import "./resources/health";
import "./resources/viewer";

export const schema: GraphQLSchema = builder.toSchema();
