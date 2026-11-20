// The backend's entry point.
import { failStartup, start } from "./server";

export const server = await start(process.env).catch(failStartup);
