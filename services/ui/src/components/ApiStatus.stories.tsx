import type { Meta, StoryObj } from "@storybook/react-vite";
import { ApiStatusBadge } from "./ApiStatus";

const meta = {
  title: "Status/ApiStatus",
  id: "app-apistatus",
  component: ApiStatusBadge,
  args: { state: "online" },
  parameters: {
    docs: {
      description: {
        component:
          "Shows whether the API answers, in the header. Render ApiStatus, which reads the health query; use ApiStatusBadge only to show a fixed state.",
      },
    },
  },
} satisfies Meta<typeof ApiStatusBadge>;

export default meta;
type Story = StoryObj<typeof meta>;

export const Online: Story = {};
export const Checking: Story = { args: { state: "checking" } };
export const Offline: Story = { args: { state: "offline" } };
export const Unconfigured: Story = { args: { state: "unconfigured" } };
export const Dark: Story = { globals: { theme: "dark" } };
