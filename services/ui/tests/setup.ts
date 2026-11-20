import { afterEach } from "bun:test";
import { GlobalRegistrator } from "@happy-dom/global-registrator";

GlobalRegistrator.register({ url: "http://localhost:3000/" });
// Imported after registration: Testing Library binds to the DOM globals.
const { cleanup } = await import("@testing-library/react");
afterEach(cleanup);
// Components translate through the shared instance, as in the app.
await import("@/i18n");
