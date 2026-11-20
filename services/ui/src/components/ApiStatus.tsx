import type { ReactElement } from "react";
import { useTranslation } from "react-i18next";
import { useHealth, type ApiState } from "@/hooks/useHealth";
import { cn } from "@/lib/utils";

const dot: Record<ApiState, string> = {
  checking: "bg-muted-foreground animate-pulse motion-reduce:animate-none",
  online: "bg-success",
  offline: "bg-destructive",
  unconfigured: "bg-muted-foreground",
};

const label = {
  checking: "api.checking",
  online: "api.online",
  offline: "api.offline",
  unconfigured: "api.unconfigured",
} as const satisfies Record<ApiState, string>;

/** A small pill saying whether the API answers. */
export function ApiStatusBadge({ state }: { state: ApiState }): ReactElement {
  const { t } = useTranslation();
  return (
    <span
      role="status"
      data-slot="api-status"
      data-state={state}
      className="inline-flex items-center gap-1.5 rounded-full border border-border px-2.5 py-1 text-xs text-muted-foreground"
    >
      <span aria-hidden className={cn("size-1.5 rounded-full", dot[state])} />
      {t(label[state])}
    </span>
  );
}

/** The API's live status, read through the health query. */
export function ApiStatus(): ReactElement {
  return <ApiStatusBadge state={useHealth()} />;
}
