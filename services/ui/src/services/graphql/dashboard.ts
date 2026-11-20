import { graphql } from "./generated";

// The dashboard's stats: every user, and sign-ups on each of the last 7 days.
export const DashboardQuery = graphql(`
  query Dashboard {
    dashboard {
      totalUsers
      signUps {
        day
        count
      }
    }
  }
`);
