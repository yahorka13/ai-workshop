import { graphql } from "./generated";

// The backend's health, which the header shows as the API's status.
export const HealthQuery = graphql(`
  query Health {
    health {
      ok
    }
  }
`);
