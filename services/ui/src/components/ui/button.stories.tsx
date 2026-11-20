import type { Meta, StoryObj } from "@storybook/react-vite";
import { Button } from "./button";

const meta = {
  title: "Actions/Button",
  id: "ui-button",
  component: Button,
  args: { children: "Save changes" },
  parameters: {
    docs: {
      description: {
        component:
          "Use it for an action on the page, labelled with what it does. Use the default variant for the main action, outline for a second one, and the link variant, or a link with asChild, to go to another page.",
      },
    },
  },
} satisfies Meta<typeof Button>;

export default meta;
type Story = StoryObj<typeof meta>;

export const Default: Story = {};
export const Outline: Story = { args: { variant: "outline" } };
export const Secondary: Story = { args: { variant: "secondary" } };
export const Ghost: Story = { args: { variant: "ghost" } };
export const Destructive: Story = {
  args: { variant: "destructive", children: "Delete" },
};
export const Link: Story = {
  args: { variant: "link", children: "Go to home" },
};
export const Small: Story = { args: { size: "sm" } };
export const Large: Story = { args: { size: "lg" } };
export const Disabled: Story = { args: { disabled: true } };
export const Dark: Story = { globals: { theme: "dark" } };
