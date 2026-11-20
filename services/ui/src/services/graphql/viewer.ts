import { graphql } from "./generated";

// The signed-in user, or null: what the app's routes and header show.
export const ViewerQuery = graphql(`
  query Viewer {
    viewer {
      id
      name
      email
    }
  }
`);
