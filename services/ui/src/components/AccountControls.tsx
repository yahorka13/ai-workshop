import type { ReactElement } from "react";
import { useTranslation } from "react-i18next";
import { useNavigate } from "react-router";
import { Button } from "@/components/ui/button";
import { useSession } from "@/hooks/useSession";

// Who is signed in, and signing out, which always ends on the login page.
export function AccountControls({ name }: { name: string }): ReactElement {
  const { t } = useTranslation();
  const session = useSession();
  const navigate = useNavigate();
  return (
    <div className="flex items-center gap-2">
      <span className="text-sm text-muted-foreground">{name}</span>
      <Button
        variant="ghost"
        size="sm"
        onClick={() => {
          void session.signOut().then(() => navigate("/login"));
        }}
      >
        {t("account.signOut")}
      </Button>
    </div>
  );
}
