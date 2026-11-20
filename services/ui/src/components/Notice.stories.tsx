import type { Meta, StoryObj } from "@storybook/react-vite";
import { Button } from "./ui/button";
import { Notice } from "./Notice";

const meta = {
  title: "Layout/Notice",
  id: "app-notice",
  component: Notice,
  args: {
    title: "Page not found",
    body: "Nothing lives at this address.",
    children: <Button variant="outline">Go to home</Button>,
  },
  parameters: {
    docs: {
      description: {
        component:
          "A full-page message, such as the error or not-found screen: the title is the page heading and the children are its actions.",
      },
    },
  },
} satisfies Meta<typeof Notice>;

export default meta;
type Story = StoryObj<typeof meta>;

export const Default: Story = {};
export const TwoActions: Story = {
  args: {
    title: "Something went wrong",
    body: "This screen could not be shown.",
    children: (
      <>
        <Button>Reload</Button>
        <Button variant="outline">Go to home</Button>
      </>
    ),
  },
};
export const Dark: Story = { globals: { theme: "dark" } };
