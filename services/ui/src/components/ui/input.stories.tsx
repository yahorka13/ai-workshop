import type { Meta, StoryObj } from "@storybook/react-vite";
import { Input } from "./input";

const meta = {
  title: "Inputs/Input",
  id: "ui-input",
  component: Input,
  args: { "aria-label": "Email", placeholder: "name@example.com" },
  parameters: {
    docs: {
      description: {
        component:
          "Use it for one line of text a person types, with a Label naming it. Set aria-invalid when its value was refused.",
      },
    },
  },
} satisfies Meta<typeof Input>;

export default meta;
type Story = StoryObj<typeof meta>;

export const Default: Story = {};
export const Filled: Story = { args: { defaultValue: "demo@example.com" } };
export const Invalid: Story = { args: { "aria-invalid": true } };
export const Disabled: Story = { args: { disabled: true } };
export const Dark: Story = { globals: { theme: "dark" } };
