import type { Meta, StoryObj } from "@storybook/react-vite";
import { AccountControls } from "./AccountControls";

const meta = {
  title: "Navigation/AccountControls",
  id: "app-accountcontrols",
  component: AccountControls,
  args: { name: "Demo User" },
  parameters: {
    docs: {
      description: {
        component:
          "The signed-in user's name and Sign out, at the right of the header. Signing out ends the session and opens the login page, even when the API cannot be reached.",
      },
    },
  },
} satisfies Meta<typeof AccountControls>;

export default meta;
type Story = StoryObj<typeof meta>;

export const Default: Story = {};
export const Dark: Story = { globals: { theme: "dark" } };
