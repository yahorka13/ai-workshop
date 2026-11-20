import type { ReactElement } from "react";
import { cn } from "@/lib/utils";

// A component as the ui writes them: class names, a condition that picks
// one, and a text it renders.
export function Probe({ active }: { active: boolean }): ReactElement {
  return (
    <div className="probe-box">
      <p
        className={cn(
          "probe-a",
          active && "probe-b",
        )}
      >
        {"probe text"}
      </p>
    </div>
  );
}
