import type { ReactElement } from "react";
import { Outlet } from "react-router";
import { AppHeader } from "@/components/AppHeader";

export function RootLayout(): ReactElement {
  return (
    <div className="min-h-svh bg-background font-sans text-foreground">
      <AppHeader />
      <main className="mx-auto w-full max-w-5xl px-4 py-10 sm:px-6">
        <Outlet />
      </main>
    </div>
  );
}
