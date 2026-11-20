# ui service

Client-only React SPA. Read the repository `AGENTS.md` first. This service
owns its manifest, generated lockfile, configuration, tooling, tests,
Dockerfile and nginx config; it imports nothing from another service.

## Stack

React 19, React Router 8 (data mode; `RouterProvider` from
`react-router/dom`), Vite on Bun 1.4.3, Tailwind 4, shadcn/ui (Radix,
`radix-nova`, neutral), i18next. The stack serves static files from pinned
nginx on port 3000: the app at `/` and the Storybook build at `/storybook/`.
There is no dev server and no hot reload.

## Run and check

- Gates: `bin/check ui` (contracts, lint, typecheck, unit and integration
  tests, coverage at 100% lines and functions over every `src/` module, and
  duplicates, unused and imports). The standard scripts are `lint`,
  `format`, `typecheck`, `test:unit`, `test:integration`, `coverage`,
  `duplicates`, `unused` and `imports`; coverage runs both suites once, so
  use the two test scripts while iterating. Lint checks formatting without
  writing; `format` rewrites.
- `duplicates` fails on a block of at least 50 tokens and 5 lines that
  appears twice in `src/`, `tests/` or `tooling/` (`.jscpd.json`, the same
  in every service). Extract the shared code into one function, component
  or module. A clone that must stay goes between
  `// jscpd:ignore-start <reason>` and `// jscpd:ignore-end`, and raises
  the ui's count in `bin/duplicate-disables.txt`.
- `unused` fails on an unused file, export, exported type or dependency
  (`knip.config.ts`: its `unused-rules` block is the same in every service;
  the entry points, including stories, tests and `.storybook/`, are the
  ui's). Delete it or stop exporting it. An export that must stay carries
  `/** @knipignore <reason> */`; a file or dependency Knip cannot see is
  listed in the config with `// knipignore: <reason>`. Each raises the ui's
  count in `bin/unused-disables.txt`.
- Every test callback needs a direct, completed, non-snapshot assertion
  (`tooling/test-policy.mjs`). Tests run on `bun test` with happy-dom and
  Testing Library; `tests/setup.ts` registers the DOM and loads i18n.
- Declare the narrowest true return type: a component returns `ReactElement`
  or `ReactElement | null`, and `ReactNode` only when it returns its children,
  a string or an array; never `unknown`, `object` or a wider union to satisfy
  the return-type rule. In tests reach a maybe-missing value with `defined` or
  `at`, and an element of a class with `instance`, from
  `tests/support/defined.ts`; never `!` or `as`.
- Validate every untrusted input (build environment, API responses) with a
  zod schema, never by hand.
- Mutation testing runs only in CI's `mutation` workflow, started by hand
  (`gh workflow run mutation -R "$(bin/repo)"`), which runs `bin/mutate ui`
  (usage in `bin/mutate --help`) in the Dockerfile's `mutate` target, with
  `stryker.config.mjs` and both suites
  (not the tests of tooling and gates). Do not run it while working. Two
  ignorers keep mutants that are not behaviour out:
  `tooling/stryker-ignore-class-names.mjs` skips class name strings (a
  `className` text, `cn(...)` and `cva(...)` arguments, a cva variant's
  classes; the condition that picks a class stays mutated), and
  `tooling/stryker-ignore-error-messages.mjs` skips the texts of thrown
  Errors. Kill a surviving mutant with a test that fails on it; one that
  cannot change behaviour is marked on the line above it,
  `// Stryker disable next-line <mutator>: <reason>`, and raises `ui` in
  `bin/mutation-disables.txt`.
- Stack: `bin/up --watch` (root `AGENTS.md`, Commands) rebuilds the image on
  every change under `services/ui` and serves it at the URL `bin/up` prints;
  reload the page to see it.
- The running ui container is nginx, so it has no Bun. Run Bun in the pinned
  image instead, for example
  `docker run --rm -v "$PWD/services/ui:/app" -w /app oven/bun:1.4.3 bun add --exact <pkg>@<version>`.
  Pin every version exactly and regenerate the lockfile only this way.
- The image's serving rules (client routes, caching, source maps,
  `/storybook/`) are proven by `bin/tests/ui-static.e2e.sh`.
- Prove UI changes in a browser against the running stack; the root
  `AGENTS.md` (Definition of done, item 3) says which browser.

## Source layout

```
src/
  main.tsx        bootstrap: styles, i18n, mount <App/>
  app/            App (providers go here), routes, ErrorPage
  layouts/        RootLayout
  pages/<name>/   one folder per screen, plus what only that screen uses
  components/     shared components; components/ui/ holds shadcn primitives
  hooks/          shared hooks
  services/       shared adapters (the GraphQL client goes here)
  i18n/           setup, types and locales/en/*.json
  lib/            pure helpers
  styles/         index.css (Tailwind entry) and theme.css (tokens)
```

Code starts in the page folder that uses it. When a second page or the
layout needs it, move it to `components/`, `hooks/` or `services/`. A page
folder never imports another page folder (lint enforces this); import shared
code through `@/`.

The `imports` gate (`.dependency-cruiser.mjs`) fails on an import cycle and on
these layer rules, naming the rule and how to fix it:

- `lib/` imports nothing else from `src/`.
- `services/` never imports `hooks/`, `components/`, `layouts/`, `pages/` or
  `app/`.
- `hooks/` never imports `components/`, `layouts/`, `pages/` or `app/`.
- `components/` reaches services only through hooks, and never imports
  `pages/`, `layouts/` or `app/`.
- Only `main.tsx` imports `app/`.
- `src/` never imports `tests/` or `tooling/`.

Stories are exempt from the layer rules, not from cycles. The rules shared by
every service sit in the config's `import-rules` block. A one-off exception is
a `pathNot` entry on the rule it breaks, with `// import-exception: <reason>`
on its line, and raises the ui's count in `bin/import-disables.txt`.

## Backend contract

`consumes.txt` declares `backend`, so `bin/check ui` and `bin/contracts`
mount its `contracts/` read-only at `/contracts/backend/`. Operations live in
`src/services/graphql/`, one module per operation, written with `graphql()`
from `./generated`; the typed documents in `src/services/graphql/generated/`
are generated from `/contracts/backend/schema.graphql` by
`tooling/contracts.ts`. `Date`, `DateTime`, `Decimal` and `BigInt` are typed
`string`: never coerce them to `number` or `Date`. Never edit the generated
folder: change an operation or the backend source, then run
`bin/contracts generate` from the repository root and commit the result. The
`contracts` gate, first in `bin/check ui`, fails on drift, a hand edit or an
extra file, and an operation selecting a field the schema lacks fails
generation.

The build reads the API's origin from `VITE_API_URL`
(`src/services/graphql/config.ts`); anything but a bare http(s) origin leaves
the API not configured, and then every operation fails without a request.

## Data hooks

One hook per front-end model in `src/hooks/`, named `use` plus the model's
plural (`useContacts`); a model the user has exactly one of keeps the
singular (`useHealth`). Name hooks after models, never after the backend's
nesting or a join, and add no hook only for tests. A data hook reads through
Apollo's `useQuery` on the one client (`src/services/graphql/client.ts`,
provided by `ApiProvider` in `App`): every query shows what the cache holds
and refreshes it (`cache-and-network`, the client's default). Test a hook's
component with `MockedProvider` from `@apollo/client/testing/react` inside
`ApiOriginContext`.

## Add a screen

1. Write the failing tests: a unit test for the page in `tests/unit/pages/`
   and a route test in `tests/integration/routes.test.tsx`, tagged with the
   scenario IDs.
2. Create `src/pages/<name>/<Name>Page.tsx`.
3. Register its route in `src/app/routes.tsx`, before the `*` route.
4. Add every string to `src/i18n/locales/en/common.json`; typecheck rejects
   an unknown key and the integration tests reject an unused one.
5. Run `bin/check ui`, then prove it in the browser.

## Add a shadcn primitive

Only when a screen uses it:
`docker run --rm -v "$PWD/services/ui:/app" -w /app oven/bun:1.4.3 bunx --bun shadcn@4.21.5 add <name> -y`,
then point its `cn` import at `@/lib/utils` and drop any `cn` package the CLI
adds, re-pin any other dependency it adds, run `format`, give it a return
type, and add its tests and story. Generated files are ours to edit.

## Component base

`src/components/` is the one design system. It holds shadcn primitives in
`ui/` and the product's own components beside it. Storybook documents it.

- **Theme.** `src/styles/theme.css` holds the tokens (shadcn's neutral
  palette) and maps them to Tailwind: `background`, `foreground`, `card`,
  `primary`, `secondary`, `muted`, `accent`, `destructive`, `border`,
  `input`, `ring`, the radii and the system font stack. Never hard-code a
  colour: add a token first. Lint rejects a hex colour in an arbitrary value
  (`bg-[#fff]`) under `src/`. Dark follows the system preference; `.dark` or
  `[data-theme="dark"]` forces it, `[data-theme="light"]` forces light.
- **API.** Use the shadcn shape: `cva` variants and sizes, `data-slot`,
  `data-variant` and `data-size`, and `asChild` where it fits. Icons are
  lucide elements. Put content in children rather than props. Merge classes
  with `cn` from `@/lib/utils`.
- **Stories.** Every component under `src/components/` has a
  `<Name>.stories.tsx` next to it, whose meta has a usage description
  (`parameters.docs.description.component`) and which exports one story per
  variant and state plus a `Dark` one; the unit tests fail otherwise. Every
  story address is listed in `tooling/story-ids.txt`, which only grows
  (`bun run story-ids` appends new ones), and a listed address that
  disappears fails the unit tests: moving a story keeps its address by
  setting the meta's `id:` to the old one.
- **Storybook** runs locally with `bun run storybook` in the checks image
  (publish port 6006), and the stack serves its build at `/storybook/`.
- **Missing components.** A screen that needs a component the base lacks
  adds it here first, under these rules, rather than building it inline.
