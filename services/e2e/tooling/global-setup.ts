import { forward, parseForwards } from "./forward";

/* Starts the forwards bin/e2e asks for in E2E_FORWARDS before any test runs,
   and stops them when the run ends. Workers share the container's network,
   so every browser and request context reaches them. */

export default async function globalSetup(): Promise<() => void> {
  const servers = await Promise.all(
    parseForwards(process.env.E2E_FORWARDS ?? "").map((entry) =>
      forward(entry.listenPort, entry.host, entry.port),
    ),
  );
  // Stop accepting; open connections must not keep the run from ending.
  return () => {
    for (const server of servers) server.close().unref();
  };
}
