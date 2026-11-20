import { useQuery } from "@apollo/client/react";
import { use } from "react";
import { z } from "zod";
import { ApiOriginContext } from "@/services/graphql/origin";
import { ViewerQuery } from "@/services/graphql/viewer";

type Viewer = { id: string; name: string; email: string };

export type ViewerState =
  | { status: "loading" }
  | { status: "signedOut" }
  | { status: "signedIn"; viewer: Viewer };

// The API's answer is untrusted: anything but a viewer is signed out.
const viewerAnswer = z.object({
  viewer: z.object({ id: z.string(), name: z.string(), email: z.string() }),
});

/** Who is signed in. A failed request, or no API, reads as signed out. */
export function useViewer(): ViewerState {
  const configured = use(ApiOriginContext) !== undefined;
  const { data, error } = useQuery(ViewerQuery, { skip: !configured });
  if (!configured || error) return { status: "signedOut" };
  if (data === undefined) return { status: "loading" };
  const answer = viewerAnswer.safeParse(data);
  if (!answer.success) return { status: "signedOut" };
  const { id, name, email } = answer.data.viewer;
  return { status: "signedIn", viewer: { id, name, email } };
}
