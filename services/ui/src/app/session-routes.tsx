import type { ReactElement } from "react";
import { Navigate, Outlet, useLocation, useSearchParams } from "react-router";
import { useViewer } from "@/hooks/useViewer";
import { safeNext } from "@/lib/next-path";

// Every screen but the login page: signed out, the user is sent to sign in,
// and comes back to this path afterwards. Nothing shows while it is unknown.
export function RequireSession(): ReactElement | null {
  const viewer = useViewer();
  const { pathname, search } = useLocation();
  if (viewer.status === "loading") return null;
  if (viewer.status === "signedOut")
    return (
      <Navigate
        to={`/login?next=${encodeURIComponent(pathname + search)}`}
        replace
      />
    );
  return <Outlet />;
}

// The login page: a signed-in user goes where the page would have sent them.
export function SignedOutOnly(): ReactElement | null {
  const viewer = useViewer();
  const [params] = useSearchParams();
  if (viewer.status === "loading") return null;
  if (viewer.status === "signedIn")
    return <Navigate to={safeNext(params.get("next"))} replace />;
  return <Outlet />;
}
