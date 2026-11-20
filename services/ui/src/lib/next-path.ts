// Where to go after signing in: a path inside the app, never another origin.

// Stands in for the app's origin: `next` is read as a browser would read it
// as a link on the app's page, and kept only if it stays on that origin.
const APP = "http://app.invalid";

/** `next` when it is a path in this app, otherwise the home screen. */
export function safeNext(next: string | null): string {
  if (next?.startsWith("/") !== true) return "/";
  const url = URL.parse(next, APP);
  if (url?.origin !== APP) return "/";
  return url.pathname + url.search + url.hash;
}
