// How root fields are named (AGENTS.md: GraphQL contract).
import { expect, test } from "bun:test";
import {
  GraphQLList,
  GraphQLNonNull,
  GraphQLObjectType,
  GraphQLSchema,
  GraphQLString,
} from "graphql";
import { schema } from "../../src/graphql/schema";
import { namingProblems } from "../support/naming";

test("[contracts-86cd7d] the backend's root fields follow the naming rule", () => {
  expect(namingProblems(schema)).toEqual([]);
});

test("[contracts-86cd7d] a verb-named query fails, naming the field", () => {
  const Contact = new GraphQLObjectType({
    name: "Contact",
    fields: { name: { type: GraphQLString } },
  });
  const verbs = new GraphQLSchema({
    query: new GraphQLObjectType({
      name: "Query",
      fields: {
        contacts: { type: new GraphQLNonNull(new GraphQLList(Contact)) },
        getContacts: { type: new GraphQLList(Contact) },
      },
    }),
    mutation: new GraphQLObjectType({
      name: "Mutation",
      fields: {
        createContact: { type: Contact },
        archiveContact: { type: Contact },
      },
    }),
  });
  expect(namingProblems(verbs)).toEqual([
    "query getContacts: name it contacts",
    "mutation archiveContact: start it with create, update or delete",
  ]);
});
