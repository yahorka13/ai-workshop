import type { ReactElement } from "react";
import { ErrorPage } from "@/app/ErrorPage";

// The layout or its header threw: the error screen without the layout, which
// may be what failed.
export function LayoutErrorPage(): ReactElement {
  return (
    <div className="min-h-svh bg-background font-sans text-foreground">
      <main className="mx-auto w-full max-w-5xl px-4 py-10 sm:px-6">
        <ErrorPage />
      </main>
    </div>
  );
}
