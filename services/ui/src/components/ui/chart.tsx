// shadcn's chart, trimmed to what the product uses: a container that sizes a
// Recharts chart and names each series' colour as --color-<key>, and a
// tooltip in the theme's look. Colours are theme tokens, so dark mode follows.
import * as React from "react";
import * as RechartsPrimitive from "recharts";
import { cn } from "@/lib/utils";

/** Each series by its data key: the label it shows and its colour, a theme token. */
export type ChartConfig = Record<string, { label: string; color: string }>;

const ChartContext = React.createContext<ChartConfig>({});

// Recharts measures the container; this is its size before the first measure.
const INITIAL_DIMENSION = { width: 320, height: 200 } as const;

function ChartContainer({
  config,
  className,
  style,
  children,
  ...props
}: Omit<React.ComponentProps<"div">, "children"> & {
  config: ChartConfig;
  children: React.ComponentProps<
    typeof RechartsPrimitive.ResponsiveContainer
  >["children"];
}): React.ReactElement {
  const colors: Record<string, string> = Object.fromEntries(
    Object.entries(config).map(([key, item]) => [`--color-${key}`, item.color]),
  );
  return (
    <ChartContext value={config}>
      <div
        data-slot="chart"
        className={cn(
          "flex aspect-video justify-center text-xs [&_.recharts-cartesian-axis-tick_text]:fill-muted-foreground [&_.recharts-layer]:outline-hidden [&_.recharts-rectangle.recharts-tooltip-cursor]:fill-muted [&_.recharts-surface]:outline-hidden",
          className,
        )}
        style={{ ...colors, ...style }}
        {...props}
      >
        <RechartsPrimitive.ResponsiveContainer
          initialDimension={INITIAL_DIMENSION}
        >
          {children}
        </RechartsPrimitive.ResponsiveContainer>
      </div>
    </ChartContext>
  );
}

const ChartTooltip = RechartsPrimitive.Tooltip;

type TooltipItem = { dataKey?: unknown; value?: unknown };

function text(value: unknown): string {
  return typeof value === "number" || typeof value === "string"
    ? String(value)
    : "";
}

/** The tooltip's content: the hovered label, then each series' label and value. */
function ChartTooltipContent({
  active,
  payload,
  label,
  labelFormatter = text,
}: {
  active?: boolean;
  payload?: readonly TooltipItem[];
  label?: unknown;
  labelFormatter?: (label: string) => string;
}): React.ReactElement | null {
  const config = React.use(ChartContext);
  if (active !== true || payload === undefined || payload.length === 0)
    return null;
  return (
    <div
      data-slot="chart-tooltip"
      className="grid min-w-32 gap-1.5 rounded-lg border border-border/50 bg-background px-2.5 py-1.5 text-xs shadow-xl"
    >
      <div className="font-medium">{labelFormatter(text(label))}</div>
      {payload.map((item) => {
        const key = text(item.dataKey);
        return (
          <div key={key} className="flex items-center gap-2">
            <span
              aria-hidden
              className="size-2.5 shrink-0 rounded-[2px]"
              style={{ backgroundColor: `var(--color-${key})` }}
            />
            <span className="flex-1 text-muted-foreground">
              {config[key]?.label ?? key}
            </span>
            <span className="font-medium text-foreground tabular-nums">
              {text(item.value)}
            </span>
          </div>
        );
      })}
    </div>
  );
}

export { ChartContainer, ChartTooltip, ChartTooltipContent };
