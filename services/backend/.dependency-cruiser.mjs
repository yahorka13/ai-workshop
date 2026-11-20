// The imports gate (bun run imports): import cycles and layer rules.
/** @type {import("dependency-cruiser").IConfiguration} */
export default {
  forbidden: [
    // import-rules:start
    {
      name: "no-circular",
      severity: "error",
      comment:
        "These modules import each other: move the shared part into a module both import.",
      from: {},
      to: { circular: true },
    },
    {
      name: "src-not-to-tests",
      severity: "error",
      comment:
        "Application code never imports tests: move what both need into src/.",
      from: { path: "^src/" },
      to: { path: "^tests/" },
    },
    {
      name: "src-not-to-tooling",
      severity: "error",
      comment:
        "Application code never imports tooling: move what both need into src/.",
      from: { path: "^src/" },
      to: { path: "^tooling/" },
    },
    {
      name: "not-to-unresolvable",
      severity: "error",
      comment:
        "This import resolves to nothing: fix its path or add the package.",
      from: {},
      to: { couldNotResolve: true },
    },
    // import-rules:end
    {
      name: "graphql-not-to-db",
      severity: "error",
      comment:
        "GraphQL code never imports the database: reach data through a domain module such as src/health.ts.",
      from: { path: "^src/graphql/" },
      to: { path: "^src/db/" },
    },
    {
      name: "http-not-to-graphql-or-db",
      severity: "error",
      comment:
        "HTTP middleware never imports GraphQL or the database: wire them together in src/app.ts.",
      from: { path: "^src/http/" },
      to: { path: "^src/(graphql|db)/" },
    },
    {
      name: "db-not-to-graphql-or-http",
      severity: "error",
      comment:
        "Database code never imports GraphQL or HTTP: it serves domain modules, not the API.",
      from: { path: "^src/db/" },
      to: { path: "^src/(graphql|http)/" },
    },
    {
      name: "only-index-imports-server",
      severity: "error",
      comment:
        "Only src/index.ts starts the server: other modules build the app with createApp from src/app.ts.",
      from: { path: "^src/", pathNot: "^src/index\\.ts$" },
      to: { path: "^src/server\\.ts$" },
    },
  ],
  options: {
    tsConfig: { fileName: "tsconfig.json" },
    tsPreCompilationDeps: true,
    doNotFollow: { path: "node_modules" },
    // Type-only packages resolve too: an exports map with only "types" and
    // "default" (typescript-eslint), or only a "types" entry
    // (@graphql-typed-document-node/core).
    enhancedResolveOptions: {
      exportsFields: ["exports"],
      conditionNames: ["import", "require", "node", "default", "types"],
      mainFields: ["module", "main", "types", "typings"],
    },
  },
};
