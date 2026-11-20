// The Health resource: whether the backend can serve.
import { checkHealth, type Health } from "../../health";
import { builder } from "../builder";

const HealthType = builder.objectRef<Health>("Health").implement({
  description: "Whether the backend can serve: its database answers.",
  fields: (t) => ({
    ok: t.exposeBoolean("ok", { description: "True while it can serve." }),
  }),
});

builder.queryType({
  fields: (t) => ({
    health: t.field({
      type: HealthType,
      description: "The backend's health, as GET /health answers it.",
      resolve: (_root, _args, context) => checkHealth(context.probe),
    }),
  }),
});
