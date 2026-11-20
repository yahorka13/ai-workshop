import type { Meta, StoryObj } from "@storybook/react-vite";
import { Bar, BarChart, XAxis } from "recharts";
import {
  ChartContainer,
  ChartTooltip,
  ChartTooltipContent,
  type ChartConfig,
} from "./chart";

const config = {
  count: { label: "Sign-ups", color: "var(--color-chart-1)" },
} satisfies ChartConfig;

const data = [
  { day: "Wed", count: 0 },
  { day: "Thu", count: 1 },
  { day: "Fri", count: 0 },
  { day: "Sat", count: 3 },
  { day: "Sun", count: 2 },
  { day: "Mon", count: 0 },
  { day: "Tue", count: 4 },
];

const meta = {
  title: "Data/Chart",
  id: "ui-chart",
  component: ChartContainer,
  args: {
    config,
    className: "max-w-md",
    children: (
      <BarChart data={data}>
        <XAxis dataKey="day" tickLine={false} axisLine={false} />
        <ChartTooltip content={<ChartTooltipContent />} />
        <Bar dataKey="count" fill="var(--color-count)" radius={4} />
      </BarChart>
    ),
  },
  parameters: {
    docs: {
      description: {
        component:
          "Use it to size a Recharts chart and colour it from the theme: name each series in config with its label and a token such as var(--color-chart-1), then fill with var(--color-<key>). ChartTooltip with ChartTooltipContent shows the hovered values.",
      },
    },
  },
} satisfies Meta<typeof ChartContainer>;

export default meta;
type Story = StoryObj<typeof meta>;

export const Default: Story = {};
export const Dark: Story = { globals: { theme: "dark" } };
