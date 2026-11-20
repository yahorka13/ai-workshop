import { useState, type ReactElement } from "react";
import { RouterProvider } from "react-router/dom";
import { createBrowserRouter } from "react-router";
import { createRoutes } from "@/app/routes";
import { apiOrigin } from "@/services/graphql/config";
import { ApiProvider } from "@/services/graphql/provider";

// Providers wrap the router here. The router is created once: a new one on a
// re-render would drop its navigation state.
export function App(): ReactElement {
  const [router] = useState(() => createBrowserRouter(createRoutes()));
  return (
    <ApiProvider origin={apiOrigin}>
      <RouterProvider router={router} />
    </ApiProvider>
  );
}
