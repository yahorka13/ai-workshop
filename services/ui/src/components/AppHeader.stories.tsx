import type { Meta, StoryObj } from "@storybook/react-vite";
import { AppHeader } from "./AppHeader";

const meta = {
  title: "Navigation/AppHeader",
  id: "app-appheader",
  component: AppHeader,
  parameters: {
    layout: "fullscreen",
    docs: {
      description: {
        component:
          "The top bar of every screen, rendered once by the root layout: the product name linking home, the main navigation, the API status and the signed-in user with Sign out. Add a screen's link to its navigation; do not render a second header.",
      },
    },
  },
} satisfies Meta<typeof AppHeader>;

export default meta;
type Story = StoryObj<typeof meta>;

/** On the dashboard, Dashboard is the current page. */
export const Default: Story = {};

export const Dark: Story = { globals: { theme: "dark" } };
