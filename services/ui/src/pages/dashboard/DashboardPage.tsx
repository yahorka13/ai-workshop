import type { ReactElement } from "react";
import { useTranslation } from "react-i18next";
import { Notice } from "@/components/Notice";
import { Button } from "@/components/ui/button";
import { useDashboard } from "@/hooks/useDashboard";
import { SignUpsChart } from "./SignUpsChart";
import { StatTile } from "./StatTile";

// The screen a signed-in user lands on: two stat tiles and a chart of the
// last 7 days' sign-ups, all from one dashboard query.
export function DashboardPage(): ReactElement {
  const { t } = useTranslation();
  const state = useDashboard();
  if (state.status === "failed") {
    return (
      <Notice title={t("dashboard.failed")} body={t("dashboard.retry")}>
        <Button
          onClick={() => {
            window.location.reload();
          }}
        >
          {t("error.reload")}
        </Button>
      </Notice>
    );
  }
  const { dashboard } = state; // undefined while loading
  return (
    <section className="space-y-6">
      <div className="space-y-1">
        <h1 className="text-2xl font-semibold tracking-tight">
          {t("dashboard.title")}
        </h1>
        <p className="text-muted-foreground">
          {t("dashboard.lead", { name: t("app.name") })}
        </p>
      </div>
      <div className="grid gap-4 sm:grid-cols-2">
        <StatTile
          label={t("dashboard.totalUsers")}
          value={dashboard?.totalUsers}
        />
        <StatTile
          label={t("dashboard.weekSignUps")}
          value={dashboard?.signUps.reduce((sum, day) => sum + day.count, 0)}
        />
      </div>
      <SignUpsChart signUps={dashboard?.signUps} />
    </section>
  );
}
