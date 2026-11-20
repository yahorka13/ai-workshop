// The Viewer resource: the signed-in user a request is from.
import type { Viewer } from "../../viewer";
import { builder } from "../builder";

const ViewerType = builder.objectRef<Viewer>("Viewer").implement({
  description: "The signed-in user a request is from.",
  fields: (t) => ({
    id: t.exposeID("id", { description: "The user's ID." }),
    name: t.exposeString("name", { description: "The user's name." }),
    email: t.exposeString("email", { description: "The user's email." }),
  }),
});

builder.queryField("viewer", (t) =>
  t.field({
    type: ViewerType,
    nullable: true,
    description: "The signed-in user, or null for a signed-out request.",
    resolve: (_root, _args, context) => context.viewer,
  }),
);
