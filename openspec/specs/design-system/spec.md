# design-system Specification

## Purpose
The UI's component base: its theme and styling rules, and the Storybook
gallery that documents every shared component.

## Requirements

### Requirement: Every shared component has a story
The UI's unit tests SHALL fail on a component module under `src/components/` with no `.stories.tsx` file next to it.

#### Scenario: [design-system-e6184f] A component without a story fails
- **WHEN** `src/components/Example.tsx` exists with no `src/components/Example.stories.tsx`
- **THEN** `bun run test:unit` fails naming `src/components/Example.tsx`
- **NO E2E** internal-rule: services/ui/tests/unit/stories.test.ts

### Requirement: Every story file describes its component's use
The UI's unit tests SHALL fail on a story file whose meta has no non-empty component description.

#### Scenario: [design-system-9bfd31] A story without a usage description fails
- **WHEN** a story file's meta has no `parameters.docs.description.component`
- **THEN** `bun run test:unit` fails naming the story file
- **NO E2E** internal-rule: services/ui/tests/unit/stories.test.ts

### Requirement: Every story file shows the dark theme
The UI's unit tests SHALL fail on a story file with no `Dark` story.

#### Scenario: [design-system-f9f8f3] A story file without a Dark story fails
- **WHEN** a story file exports no story named `Dark`
- **THEN** `bun run test:unit` fails naming the story file
- **NO E2E** internal-rule: services/ui/tests/unit/stories.test.ts

### Requirement: A recorded story address never disappears
The UI's unit tests SHALL fail when an address listed in the story ledger no longer belongs to any story.

#### Scenario: [design-system-8420a3] A removed story address fails
- **WHEN** `tooling/story-ids.txt` lists an address no story file produces
- **THEN** `bun run test:unit` fails naming the address
- **NO E2E** internal-rule: services/ui/tests/unit/story-ids.test.ts

### Requirement: Colours come from the theme
The UI's lint SHALL reject a hex colour in an arbitrary Tailwind value under `src/`.

#### Scenario: [design-system-e11a0c] A hard-coded hex colour fails lint
- **WHEN** a component under `src/` uses a class such as `bg-[#ffffff]`
- **THEN** `bun run lint` exits nonzero naming the file
- **NO E2E** internal-rule: services/ui/tests/integration/lint-rules.test.ts

### Requirement: The UI serves its component gallery
The UI's runtime image SHALL serve the Storybook build at `/storybook/`, redirect `/storybook` there with a relative `Location`, and serve Storybook's files with `Cache-Control: no-cache`.

#### Scenario: [design-system-f3c957] Storybook is served
- **WHEN** the runtime image is asked for `/storybook/`
- **THEN** it answers 200 with Storybook's entry page

#### Scenario: [design-system-a0c386] The gallery path without a slash redirects
- **WHEN** the runtime image is asked for `/storybook`, or for a directory under `/storybook/` without its trailing slash
- **THEN** it answers 301 with a relative `Location` ending in the trailing slash, so the browser stays on the port it used

#### Scenario: [design-system-e78a6b] Storybook's files are not cached
- **WHEN** the runtime image is asked for `/storybook/` or a file under it, such as its story index `index.json`
- **THEN** the answer carries `Cache-Control: no-cache`
