import type { ReactElement, ReactNode } from "react";

// A full-page message, such as an error or a missing page: its title is the
// page heading, and its children are the actions, usually buttons.
export function Notice({
  title,
  body,
  children,
}: {
  title: string;
  body: string;
  children: ReactNode;
}): ReactElement {
  return (
    <section data-slot="notice" className="max-w-prose space-y-3">
      <h1 className="text-2xl font-semibold tracking-tight">{title}</h1>
      <p className="text-muted-foreground">{body}</p>
      <div className="flex gap-2 pt-2">{children}</div>
    </section>
  );
}
