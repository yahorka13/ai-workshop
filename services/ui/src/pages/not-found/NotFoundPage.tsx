import type { ReactElement } from "react";
import { useTranslation } from "react-i18next";
import { Link } from "react-router";
import { Notice } from "@/components/Notice";
import { Button } from "@/components/ui/button";

export function NotFoundPage(): ReactElement {
  const { t } = useTranslation();
  return (
    <Notice title={t("notFound.title")} body={t("notFound.body")}>
      <Button asChild variant="outline">
        <Link to="/">{t("notFound.home")}</Link>
      </Button>
    </Notice>
  );
}
