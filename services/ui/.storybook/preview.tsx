import type { Decorator, Preview } from "@storybook/react-vite";
import { useEffect } from "react";
import { MemoryRouter } from "react-router";
import { ApiProvider } from "@/services/graphql/provider";
import "@/styles/index.css";
import "@/i18n";

// A story themes its own frame, so a Dark story on a docs page stays dark
// without turning the page dark. On the canvas, where one story renders
// alone, it themes the document too, which dialogs and tooltips portal into.
const ThemeFrame: Decorator = (Story, { globals, viewMode }) => {
  const theme = globals.theme === "dark" ? "dark" : "light";
  useEffect(() => {
    if (viewMode === "story")
      document.documentElement.setAttribute("data-theme", theme);
  }, [theme, viewMode]);
  return (
    <div data-theme={theme} className="bg-background p-4 text-foreground">
      <Story />
    </div>
  );
};

// What the app gives every screen: a router and an API client, here one with
// no API, so a component that links or reads data renders without a backend.
const AppProviders: Decorator = (Story) => (
  <ApiProvider origin={undefined}>
    <MemoryRouter>
      <Story />
    </MemoryRouter>
  </ApiProvider>
);

// Stories render on the app's theme; the toolbar switches data-theme, so
// every story can be checked in light and dark.
const preview: Preview = {
  tags: ["autodocs"],
  parameters: {
    layout: "padded",
    controls: { expanded: true },
    options: {
      // Groups by job, not by code folder; inside a group, entries sort by name.
      storySort: {
        order: [
          "Introduction",
          "Actions",
          "Inputs",
          "Overlays",
          "Feedback",
          "Status",
          "Data",
          "Navigation",
          "*",
        ],
      },
    },
  },
  globalTypes: {
    theme: {
      description: "Colour theme",
      toolbar: { title: "Theme", items: ["light", "dark"], dynamicTitle: true },
    },
  },
  initialGlobals: { theme: "light" },
  decorators: [ThemeFrame, AppProviders],
};

export default preview;
