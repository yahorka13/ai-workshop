import type { ReactElement } from "react";
import { useTranslation } from "react-i18next";
import { Link, NavLink } from "react-router";
import { AccountControls } from "@/components/AccountControls";
import { ApiStatus } from "@/components/ApiStatus";
import { useViewer } from "@/hooks/useViewer";
import { cn } from "@/lib/utils";

// The product name and the primary navigation; on the right, the API's
// status and the signed-in user.
export function AppHeader(): ReactElement {
  const { t } = useTranslation();
  const viewer = useViewer();
  return (
    <header className="border-b border-border">
      <div className="mx-auto flex h-14 w-full max-w-5xl items-center gap-6 px-4 sm:px-6">
        <Link to="/" className="text-base font-semibold tracking-tight">
          {t("app.name")}
        </Link>
        <nav aria-label={t("nav.label")} className="flex items-center gap-1">
          <NavLink
            to="/"
            end
            className={({ isActive }) =>
              cn(
                "rounded-md px-2.5 py-1.5 text-sm text-muted-foreground transition-colors hover:text-foreground",
                isActive && "bg-muted text-foreground",
              )
            }
          >
            {t("nav.dashboard")}
          </NavLink>
        </nav>
        <div className="ml-auto flex items-center gap-4">
          <ApiStatus />
          {viewer.status === "signedIn" && (
            <AccountControls name={viewer.viewer.name} />
          )}
        </div>
      </div>
    </header>
  );
}
