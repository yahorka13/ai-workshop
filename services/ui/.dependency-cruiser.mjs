// The imports gate (bun run imports): import cycles and layer rules.
// Stories document components and may import anything a layer rule forbids;
// they still count for cycles.
const STORIES = "\\.stories\\.tsx$";

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
      name: "lib-imports-nothing-internal",
      severity: "error",
      comment:
        "lib/ holds pure helpers: it imports nothing else from src/; move the shared part into lib/.",
      from: { path: "^src/lib/", pathNot: STORIES },
      to: { path: "^src/", pathNot: "^src/lib/" },
    },
    {
      name: "services-not-to-ui-layers",
      severity: "error",
      comment:
        "Services are adapters: they never import hooks, components, layouts, pages or app; pass what they need as arguments.",
      from: { path: "^src/services/", pathNot: STORIES },
      to: { path: "^src/(hooks|components|layouts|pages|app)/" },
    },
    {
      name: "hooks-not-to-ui-layers",
      severity: "error",
      comment:
        "Hooks never import components, layouts, pages or app: move the shared part into a hook, services/ or lib/.",
      from: { path: "^src/hooks/", pathNot: STORIES },
      to: { path: "^src/(components|layouts|pages|app)/" },
    },
    {
      name: "components-not-to-services",
      severity: "error",
      comment:
        "Components reach services only through a hook: add or use a hook in src/hooks/.",
      from: { path: "^src/components/", pathNot: STORIES },
      to: { path: "^src/services/" },
    },
    {
      name: "components-not-to-pages-layouts-app",
      severity: "error",
      comment:
        "Shared components never import pages, layouts or app: pass what they need as props or children.",
      from: { path: "^src/components/", pathNot: STORIES },
      to: { path: "^src/(pages|layouts|app)/" },
    },
    {
      name: "only-main-imports-app",
      severity: "error",
      comment:
        "Only src/main.tsx mounts the app: import shared code from components/, hooks/, services/ or lib/ instead.",
      from: {
        path: "^src/",
        pathNot: ["^src/main\\.tsx$", "^src/app/", STORIES],
      },
      to: { path: "^src/app/" },
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
