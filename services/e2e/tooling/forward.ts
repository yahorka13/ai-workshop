import { connect, createServer, type Server } from "node:net";

/* TCP forwards inside the e2e container: the browser opens the slot's URLs,
   127.0.0.1:<published port>, and each forward pipes that port to a service
   on the stack's Compose network, so no host networking is needed. */

export type Forward = { listenPort: number; host: string; port: number };

function port(text: string, entry: string): number {
  const value = Number(text);
  if (!/^\d+$/.test(text) || value < 1 || value > 65_535) {
    throw new Error(
      `E2E_FORWARDS entry "${entry}" is not <port>=<host>:<port>`,
    );
  }
  return value;
}

/** Parses E2E_FORWARDS, "16000=ui:3000,16002=backend:4000"; empty is none. */
export function parseForwards(spec: string): Forward[] {
  if (spec.trim() === "") return [];
  return spec.split(",").map((entry) => {
    const match = /^(\d+)=([a-z0-9.-]+):(\d+)$/.exec(entry.trim());
    if (match === null) {
      throw new Error(
        `E2E_FORWARDS entry "${entry}" is not <port>=<host>:<port>`,
      );
    }
    const [, listen = "", host = "", target = ""] = match;
    return {
      listenPort: port(listen, entry),
      host,
      port: port(target, entry),
    };
  });
}

/** Listens on 127.0.0.1:<listenPort> and pipes every connection to host:port. */
export function forward(
  listenPort: number,
  host: string,
  targetPort: number,
): Promise<Server> {
  const server = createServer((client) => {
    const upstream = connect(targetPort, host);
    // A side that fails or closes closes the other, so the browser sees a
    // closed connection rather than a hang.
    client.on("error", () => upstream.destroy());
    upstream.on("error", () => client.destroy());
    client.on("close", () => upstream.destroy());
    upstream.on("close", () => client.destroy());
    client.pipe(upstream).pipe(client);
  });
  return new Promise((resolve, reject) => {
    server.once("error", reject);
    server.listen(listenPort, "127.0.0.1", () => {
      resolve(server);
    });
  });
}
