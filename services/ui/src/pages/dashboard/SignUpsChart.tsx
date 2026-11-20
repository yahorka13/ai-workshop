import { useId, type ReactElement } from "react";
import { useTranslation } from "react-i18next";
import { Bar, BarChart, XAxis } from "recharts";
import {
  ChartContainer,
  ChartTooltip,
  ChartTooltipContent,
  type ChartConfig,
} from "@/components/ui/chart";
import { Card, CardContent } from "@/components/ui/card";
import type { Dashboard } from "@/hooks/useDashboard";
import { dayLabel } from "@/lib/day-label";

type SignUpDay = Dashboard["signUps"][number];

/** Sign-ups per day as bars; no days yet says loading. */
export function SignUpsChart({
  signUps,
}: {
  signUps: SignUpDay[] | undefined;
}): ReactElement {
  const { t } = useTranslation();
  const title = t("dashboard.chart");
  const config = {
    count: { label: t("dashboard.signUps"), color: "var(--color-chart-1)" },
  } satisfies ChartConfig;
  const titleId = useId();
  return (
    <Card role="group" aria-labelledby={titleId} className="shadow-none">
      <CardContent className="space-y-4">
        <p id={titleId} className="text-muted-foreground">
          {title}
        </p>
        {signUps === undefined ? (
          <p className="text-muted-foreground">{t("dashboard.loading")}</p>
        ) : (
          <ChartContainer
            config={config}
            role="img"
            aria-label={`${title}: ${signUps
              .map((entry) => `${dayLabel(entry.day)}: ${String(entry.count)}`)
              .join(", ")}`}
            className="max-h-64 w-full"
          >
            <BarChart data={signUps} accessibilityLayer={false}>
              <XAxis
                dataKey="day"
                tickFormatter={dayLabel}
                tickLine={false}
                axisLine={false}
              />
              <ChartTooltip
                cursor={false}
                content={<ChartTooltipContent labelFormatter={dayLabel} />}
              />
              <Bar
                dataKey="count"
                fill="var(--color-count)"
                radius={4}
                maxBarSize={48}
              />
            </BarChart>
          </ChartContainer>
        )}
      </CardContent>
    </Card>
  );
}
