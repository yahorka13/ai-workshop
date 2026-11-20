import type { RouteObject } from "react-router";
import { ErrorPage } from "@/app/ErrorPage";
import { LayoutErrorPage } from "@/app/LayoutErrorPage";
import { RequireSession, SignedOutOnly } from "@/app/session-routes";
import { RootLayout } from "@/layouts/RootLayout";
import { DashboardPage } from "@/pages/dashboard/DashboardPage";
import { LoginPage } from "@/pages/login/LoginPage";
import { NotFoundPage } from "@/pages/not-found/NotFoundPage";

// /login is for signed-out users; every other screen needs a session and
// renders inside RootLayout: add a route before the "*" one. A screen that
// throws shows ErrorPage in the layout; a layout that throws shows
// LayoutErrorPage.
export function createRoutes(): RouteObject[] {
  return [
    {
      element: <SignedOutOnly />,
      errorElement: <LayoutErrorPage />,
      children: [{ path: "/login", element: <LoginPage /> }],
    },
    {
      element: <RequireSession />,
      errorElement: <LayoutErrorPage />,
      children: [
        {
          element: <RootLayout />,
          children: [
            {
              errorElement: <ErrorPage />,
              children: [
                { index: true, element: <DashboardPage /> },
                { path: "*", element: <NotFoundPage /> },
              ],
            },
          ],
        },
      ],
    },
  ];
}
