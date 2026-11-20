import type { Meta, StoryObj } from "@storybook/react-vite";
import { Card, CardContent } from "./card";

const meta = {
  title: "Data/Card",
  id: "ui-card",
  component: Card,
  args: {
    className: "max-w-sm",
    children: <CardContent>One group of related content.</CardContent>,
  },
  parameters: {
    docs: {
      description: {
        component:
          "Use it to set one group of content apart from the page, such as a form, with its content in CardContent. The sm size tightens its spacing.",
      },
    },
  },
} satisfies Meta<typeof Card>;

export default meta;
type Story = StoryObj<typeof meta>;

export const Default: Story = {};
export const Small: Story = { args: { size: "sm" } };
export const Dark: Story = { globals: { theme: "dark" } };
