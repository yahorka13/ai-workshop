// The SignUpDay resource: how many users signed up on one day.
import type { SignUpDay } from "../../dashboard";
import { builder } from "../builder";

export const SignUpDayType = builder
  .objectRef<SignUpDay>("SignUpDay")
  .implement({
    description: "How many users signed up on one day.",
    fields: (t) => ({
      day: t.exposeString("day", {
        description: "The UTC calendar day, YYYY-MM-DD.",
      }),
      count: t.exposeInt("count", {
        description: "Users created on that day.",
      }),
    }),
  });
