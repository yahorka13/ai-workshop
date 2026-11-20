// The Dashboard resource: the stats a signed-in user lands on.
import { dashboard, type Dashboard } from "../../dashboard";
import { builder } from "../builder";
import { viewerRequired } from "../viewer-required";
import { SignUpDayType } from "./sign-up-day";

const DashboardType = builder.objectRef<Dashboard>("Dashboard").implement({
  description: "Stats for the dashboard. Signed-in users only.",
  fields: (t) => ({
    totalUsers: t.exposeInt("totalUsers", { description: "Every user." }),
    signUps: t.expose("signUps", {
      type: [SignUpDayType],
      description:
        "Sign-ups on each of the last 7 days (UTC), oldest first, ending today.",
    }),
  }),
});

builder.queryField("dashboard", (t) =>
  t.field({
    type: DashboardType,
    description:
      "The dashboard's stats. Fails with UNAUTHENTICATED when signed out.",
    resolve: (_root, _args, context) => {
      viewerRequired(context);
      return dashboard(context.userStats);
    },
  }),
);
