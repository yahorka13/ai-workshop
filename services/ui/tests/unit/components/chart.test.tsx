import { expect, test } from "bun:test";
import { render, screen } from "@testing-library/react";
import { Bar, BarChart } from "recharts";
import {
  ChartContainer,
  ChartTooltipContent,
  type ChartConfig,
} from "@/components/ui/chart";
import { withLayout } from "../../support/layout";

withLayout();

const config = {
  count: { label: "Sign-ups", color: "var(--color-chart-1)" },
} satisfies ChartConfig;

test("the container names each series' colour and holds the chart", () => {
  render(
    <ChartContainer config={config} aria-label="Sign-ups">
      <BarChart data={[{ count: 1 }]}>
        <Bar dataKey="count" />
      </BarChart>
    </ChartContainer>,
  );
  const chart = screen.getByLabelText("Sign-ups");
  expect(chart.dataset.slot).toBe("chart");
  expect(chart.style.getPropertyValue("--color-count")).toBe(
    "var(--color-chart-1)",
  );
});

function tooltip(props: Parameters<typeof ChartTooltipContent>[0]): void {
  render(
    <ChartContainer config={config}>
      <ChartTooltipContent {...props} />
    </ChartContainer>,
  );
}

test("an active tooltip shows the label, then each series' label and value", () => {
  tooltip({
    active: true,
    label: "2026-11-16",
    labelFormatter: (day) => `Day ${day}`,
    payload: [{ dataKey: "count", value: 3 }],
  });
  expect(screen.getByText("Day 2026-11-16")).toBeDefined();
  expect(screen.getByText("Sign-ups")).toBeDefined();
  expect(screen.getByText("3")).toBeDefined();
});

test("a series without a config shows its key, and a label as given", () => {
  tooltip({
    active: true,
    label: 7,
    payload: [{ dataKey: "other", value: {} }],
  });
  expect(screen.getByText("7")).toBeDefined();
  expect(screen.getByText("other")).toBeDefined();
});

test.each([
  { active: false, payload: [{ dataKey: "count", value: 1 }] },
  { active: true, payload: [] },
  { active: true },
])("an inactive or empty tooltip shows nothing: %p", (props) => {
  tooltip(props);
  expect(document.querySelector("[data-slot=chart-tooltip]")).toBeNull();
});

test("a tooltip leaves out a label or value that is not text", () => {
  tooltip({
    active: true,
    payload: [{ dataKey: "count", value: undefined }],
  });
  const tooltipElement = document.querySelector("[data-slot=chart-tooltip]");
  expect(tooltipElement?.textContent).toBe("Sign-ups");
});
