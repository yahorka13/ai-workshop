import type { ReactElement } from "react";
import { useTranslation } from "react-i18next";
import { useNavigate, useSearchParams } from "react-router";
import { ApiStatus } from "@/components/ApiStatus";
import { Card, CardContent } from "@/components/ui/card";
import { useSession } from "@/hooks/useSession";
import { safeNext } from "@/lib/next-path";
import { LoginForm } from "./LoginForm";

// The one screen outside the app's layout: sign in, then open the page the
// user asked for (?next=), or home.
export function LoginPage(): ReactElement {
  const { t } = useTranslation();
  const session = useSession();
  const navigate = useNavigate();
  const [params] = useSearchParams();
  return (
    <main className="flex min-h-svh items-center justify-center bg-background px-4 font-sans text-foreground">
      <div className="w-full max-w-sm space-y-6">
        <div className="space-y-1">
          <p className="text-sm font-semibold tracking-tight">
            {t("app.name")}
          </p>
          <h1 className="text-2xl font-semibold tracking-tight">
            {t("login.title")}
          </h1>
        </div>
        <Card className="shadow-none">
          <CardContent>
            <LoginForm
              onSignIn={async (email, password) => {
                const result = await session.signIn(email, password);
                if (result === "ok")
                  await navigate(safeNext(params.get("next")), {
                    replace: true,
                  });
                return result;
              }}
            />
          </CardContent>
        </Card>
        <ApiStatus />
      </div>
    </main>
  );
}
