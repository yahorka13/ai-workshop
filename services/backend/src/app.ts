// The HTTP application: CORS for the UI, auth, health, GraphQL, a JSON 404 and an error handler that
// never answers with a stack. It does not listen; src/index.ts does.
import { ApolloServer } from "@apollo/server";
import { expressMiddleware } from "@as-integrations/express5";
import { toNodeHandler } from "better-auth/node";
import express from "express";
import { AUTH_PATH, clientAddress, sessionViewer, type Auth } from "./auth";
import type { UserStats } from "./dashboard";
import type { Context } from "./graphql/builder";
import { keepLimitCode, queryLimits } from "./graphql/limits";
import { schema } from "./graphql/schema";
import { checkHealth, type Probe } from "./health";
import { cors } from "./http/cors";
import { errorHandler } from "./http/errors";

/** The backend's Express application, with Apollo started. */
export async function createApp(deps: {
  probe: Probe;
  /** The UI's origin, the only one CORS allows. */
  appUrl: string;
  auth: Auth;
  userStats: UserStats;
}): Promise<express.Express> {
  const apollo = new ApolloServer<Context>({
    schema,
    validationRules: queryLimits,
    formatError: keepLimitCode,
  });
  await apollo.start();
  const viewerOf = sessionViewer(deps.auth);
  const app = express();
  app.disable("x-powered-by");
  app.use(cors(deps.appUrl));
  // better-auth reads the raw body, so it is mounted before express.json().
  app.all(`${AUTH_PATH}/*splat`, clientAddress, toNodeHandler(deps.auth));
  app.get("/health", async (_request, response) => {
    const health = await checkHealth(deps.probe);
    response.status(health.ok ? 200 : 503).json(health);
  });
  app.use(
    "/graphql",
    express.json(),
    expressMiddleware(apollo, {
      context: async ({ req }) => ({
        probe: deps.probe,
        userStats: deps.userStats,
        viewer: await viewerOf(req.headers),
      }),
    }),
  );
  app.use((_request, response) => {
    response.status(404).json({ error: "Not found" });
  });
  app.use(errorHandler);
  return app;
}
