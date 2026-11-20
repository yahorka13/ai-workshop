import type { KnipConfig } from "knip";

const config: KnipConfig = {
  // unused-rules:start
  rules: {
    files: "error",
    dependencies: "error",
    devDependencies: "error",
    optionalPeerDependencies: "error",
    unlisted: "error",
    binaries: "error",
    unresolved: "error",
    exports: "error",
    nsExports: "error",
    types: "error",
    nsTypes: "error",
    enumMembers: "error",
    duplicates: "error",
  },
  ignoreExportsUsedInFile: false,
  tags: ["-knipignore"],
  // unused-rules:end
  entry: ["tests/**/*.test.ts"],
  project: ["src/**/*.ts", "tests/**/*.ts", "tooling/**/*.{ts,mjs}"],
};

export default config;
