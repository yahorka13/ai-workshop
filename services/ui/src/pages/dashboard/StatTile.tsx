import { useId, type ReactElement } from "react";
import { useTranslation } from "react-i18next";
import { Card, CardContent } from "@/components/ui/card";

/** One number on the dashboard, with its label; no value yet says loading. */
export function StatTile({
  label,
  value,
}: {
  label: string;
  value: number | undefined;
}): ReactElement {
  const { t } = useTranslation();
  const labelId = useId();
  return (
    <Card role="group" aria-labelledby={labelId} className="shadow-none">
      <CardContent className="space-y-1">
        <p id={labelId} className="text-muted-foreground">
          {label}
        </p>
        {value === undefined ? (
          <p className="text-muted-foreground">{t("dashboard.loading")}</p>
        ) : (
          <p className="text-3xl font-semibold tracking-tight tabular-nums">
            {value}
          </p>
        )}
      </CardContent>
    </Card>
  );
}
