import type { Meta, StoryObj } from "@storybook/react-vite";
import { Label } from "./label";

const meta = {
  title: "Inputs/Label",
  id: "ui-label",
  component: Label,
  args: { children: "Email", htmlFor: "email" },
  parameters: {
    docs: {
      description: {
        component:
          "Use it to name a form field, pointing htmlFor at the field's id, so clicking the name focuses the field.",
      },
    },
  },
} satisfies Meta<typeof Label>;

export default meta;
type Story = StoryObj<typeof meta>;

export const Default: Story = {};
export const Dark: Story = { globals: { theme: "dark" } };
