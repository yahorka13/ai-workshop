import type { ReactElement } from "react";
import { useTranslation } from "react-i18next";
import { Link } from "react-router";
import { Notice } from "@/components/Notice";
import { Button } from "@/components/ui/button";

// A screen that throws while rendering; the error's details stay out of the
// page. Error reporting attaches here later.
export function ErrorPage(): ReactElement {
  const { t } = useTranslation();
  return (
    <Notice title={t("error.title")} body={t("error.body")}>
      <Button
        onClick={() => {
          window.location.reload();
        }}
      >
        {t("error.reload")}
      </Button>
      <Button asChild variant="outline">
        <Link to="/">{t("error.home")}</Link>
      </Button>
    </Notice>
  );
}
