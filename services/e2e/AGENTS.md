# e2e service

Black-box end-to-end tests: Playwright drives a running stack the way a user
does. Read the repository AGENTS.md. This service owns its manifest,
lockfile, configuration, Dockerfile and tests, and ships no application code.

## Rules

- Black-box only. Tests reach the system over HTTP at the slot's URLs,
  `E2E_BASE_URL` for the app and `E2E_API_URL` for the API. Never import
  another service's code, read its files or open its database; lint rejects
  imports outside this folder.
- The suite reaches the stack through the forwards `bin/e2e` passes in
  `E2E_FORWARDS`, which `tooling/global-setup.ts` starts: the container
  listens on the slot's ports and pipes them to the services on the stack's
  network. Never call `ui:3000` or `backend:4000` directly; the browser's
  origins must be the slot URLs, or the CORS and origin checks are not the
  real ones.
- Every test title starts with the scenario IDs it covers, one per bracket:
  `test("[app-shell-c88136] an unknown path shows not found", ...)`.
  `bin/check-spec-coverage.sh` counts these citations; a scenario with no
  citation fails CI unless its spec excludes it with a
  `- **NO E2E** <category>: <reason>` line.
- One file per capability or screen: `tests/<capability>.spec.ts`. One that
  outgrows lint's file-size limit splits by area into
  `tests/<capability>-<area>.spec.ts`, with the helpers they share in
  `tests/fixtures/<capability>.ts`.
- Find elements by role and visible text, as a user would; not by CSS class.
- Each test sets up the state it needs and does not depend on another test.
- Declare the narrowest true return type; never `unknown`, `object` or a
  wider union to satisfy the return-type rule.

## Run and check

- Gates: `bin/e2e --gates` (lint, typecheck). No stack needed.
- Suite: `bin/up`, then `bin/e2e`. Pass Playwright arguments after `--`:
  `bin/e2e -- --grep "\[app-shell-c88136\]"`. `bin/e2e --changed` runs only
  the tests of the capabilities the branch changes. The report and traces
  land in `tmp/e2e/`; the command prints the path.
- Change a dependency only through the pinned image:
  `docker run --rm -v "$PWD/services/e2e:/app" -w /app oven/bun:1.4.3@sha256:ec06c3b6cea04192ae6770c434f668ca41d343ad19fa6472216c7b48be39c598 bun add --exact --dev <pkg>@<version>`.
  `@playwright/test` must match the version in the `Dockerfile`'s image.
