import { useState, type ReactElement, type SubmitEvent } from "react";
import { useTranslation } from "react-i18next";
import { z } from "zod";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import type { AuthResult } from "@/services/auth";

type Problem = Exclude<AuthResult, "ok"> | undefined;

const text = z.string(); // both fields are text inputs

function field(form: FormData, name: string): string {
  return text.parse(form.get(name));
}

// Email and password. While a sign-in is pending the button says so and
// sends nothing more; a refused or failed one says why and keeps the fields.
export function LoginForm({
  onSignIn,
}: {
  onSignIn: (email: string, password: string) => Promise<AuthResult>;
}): ReactElement {
  const { t } = useTranslation();
  const [pending, setPending] = useState(false);
  const [problem, setProblem] = useState<Problem>(undefined);

  async function submit(event: SubmitEvent<HTMLFormElement>): Promise<void> {
    event.preventDefault();
    if (pending) return;
    const form = new FormData(event.currentTarget);
    setPending(true);
    setProblem(undefined);
    const result = await onSignIn(
      field(form, "email"),
      field(form, "password"),
    );
    if (result === "ok") return;
    setProblem(result);
    setPending(false);
  }

  const invalid = problem === "invalid" || undefined;
  return (
    <form
      className="space-y-4"
      onSubmit={(event) => {
        void submit(event);
      }}
    >
      {problem !== undefined && (
        <p role="alert" className="text-sm text-destructive">
          {t(problem === "invalid" ? "login.invalid" : "login.failed")}
        </p>
      )}
      <div className="space-y-2">
        <Label htmlFor="email">{t("login.email")}</Label>
        <Input
          id="email"
          name="email"
          type="email"
          autoComplete="username"
          autoFocus
          required
          aria-invalid={invalid}
        />
      </div>
      <div className="space-y-2">
        <Label htmlFor="password">{t("login.password")}</Label>
        <Input
          id="password"
          name="password"
          type="password"
          autoComplete="current-password"
          required
          aria-invalid={invalid}
        />
      </div>
      <Button type="submit" className="w-full" disabled={pending}>
        {t(pending ? "login.submitting" : "login.submit")}
      </Button>
    </form>
  );
}
