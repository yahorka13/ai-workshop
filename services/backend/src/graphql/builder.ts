// The one Pothos schema builder every resource module adds its types to.
import SchemaBuilder from "@pothos/core";

import type { UserStats } from "../dashboard";
import type { Probe } from "../health";
import type { Viewer } from "../viewer";

// What every resolver receives: the viewer is null for a signed-out request.
export type Context = {
  probe: Probe;
  viewer: Viewer | null;
  userStats: UserStats;
};

// Fields are non-null unless a field says otherwise: a client never has to
// guard a value the backend always returns.
export const builder = new SchemaBuilder<{
  Context: Context;
  DefaultFieldNullability: false;
}>({ defaultFieldNullability: false });
