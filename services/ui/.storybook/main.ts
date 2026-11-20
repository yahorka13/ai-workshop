import type { StorybookConfig } from "@storybook/react-vite";
import remarkGfm from "remark-gfm";

// The ui's component gallery. Run it with `bun run storybook` in the checks
// image; the runtime image serves its build at /storybook/.
const config: StorybookConfig = {
  // The Introduction comes first, then the components' stories.
  stories: ["./docs/**/*.mdx", "../src/**/*.stories.tsx"],
  addons: [
    // An Accessibility panel on every story.
    "@storybook/addon-a11y",
    {
      // GitHub tables in the docs pages.
      name: "@storybook/addon-docs",
      options: {
        mdxPluginOptions: { mdxCompileOptions: { remarkPlugins: [remarkGfm] } },
      },
    },
  ],
  framework: { name: "@storybook/react-vite", options: {} },
  core: { disableTelemetry: true },
};

export default config;
