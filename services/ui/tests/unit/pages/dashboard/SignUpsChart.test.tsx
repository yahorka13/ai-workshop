import { expect, test } from "bun:test";
import { act, fireEvent, render, screen } from "@testing-library/react";
import { SignUpsChart } from "@/pages/dashboard/SignUpsChart";
import { week } from "../../../support/dashboard";
import { withLayout } from "../../../support/layout";

withLayout();

// The chart, hovered over its middle so its tooltip opens.
async function hovered(): Promise<HTMLElement> {
  render(<SignUpsChart signUps={week} />);
  const chart = screen.getByRole("img");
  const wrapper = chart.querySelector(".recharts-wrapper");
  if (!wrapper) throw new Error("no chart drawn");
  await act(async () => {
    fireEvent.mouseMove(wrapper, { clientX: 200, clientY: 100 });
    await new Promise((resolve) => setTimeout(resolve, 50));
  });
  return chart;
}

test("hovering a day shows its sign-ups in the series' colour", async () => {
  const chart = await hovered();
  expect(chart.style.getPropertyValue("--color-count")).toBe(
    "var(--color-chart-1)",
  );
  const tooltip = chart.querySelector("[data-slot=chart-tooltip]");
  expect(tooltip?.textContent).toMatch(/^\w{3} \d{1,2}Sign-ups\d+$/);
  const swatch = tooltip?.querySelector<HTMLElement>("[aria-hidden]");
  expect(swatch?.style.backgroundColor).toBe("var(--color-count)");
});

test("the chart draws bars and day labels only: no axis or tick lines, no hover cursor, no keyboard layer", async () => {
  const chart = await hovered();
  expect(
    chart.querySelectorAll(".recharts-bar-rectangle").length,
  ).toBeGreaterThan(0);
  expect(
    chart.querySelector(".recharts-cartesian-axis-tick-value"),
  ).not.toBeNull();
  expect(chart.querySelector(".recharts-cartesian-axis-line")).toBeNull();
  expect(chart.querySelector(".recharts-cartesian-axis-tick-line")).toBeNull();
  expect(chart.querySelector(".recharts-tooltip-cursor")).toBeNull();
  expect(chart.querySelector("[tabindex='0']")).toBeNull();
});
