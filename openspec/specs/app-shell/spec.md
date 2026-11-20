# app-shell Specification

## Purpose
The UI's shared frame: the layout every screen renders in, its routes and
navigation, and what a user sees on an unknown path or a failing screen.

## Requirements

### Requirement: Every screen renders in the shared layout
The UI SHALL render every route but the login page inside one layout with a header that shows the product name and the primary navigation.

#### Scenario: [app-shell-af1ebe] The home screen shows the layout
- **WHEN** a signed-in user opens `/`
- **THEN** the page shows a header with the product name and a navigation link to the home screen marked as the current page, and the home screen's heading in the main area

### Requirement: An unknown path shows the not-found screen
The UI SHALL answer a signed-in user's path no route matches with a not-found screen inside the layout that links back to the home screen.

#### Scenario: [app-shell-c88136] An unknown path is not found
- **WHEN** a signed-in user opens `/no-such-page`
- **THEN** the page shows the layout, a "Page not found" heading and a link to `/`

### Requirement: A failing screen shows the error screen
The UI SHALL replace a screen that throws while rendering with an error screen that offers to reload and to go home, without showing the error's details.

#### Scenario: [app-shell-1efddc] A thrown error shows the error screen
- **WHEN** a route's component throws while rendering
- **THEN** the page shows a "Something went wrong" heading, a reload button and a link to `/`, and not the error's message
- **NO E2E** internal-rule: services/ui/tests/unit/app/ErrorPage.test.tsx

### Requirement: The UI's server answers client routes with the app
The UI's runtime image SHALL answer any path that is not a built file with the app's entry page, uncached, and serve hashed assets with a far-future cache.

#### Scenario: [app-shell-a2332b] A deep link loads the app
- **WHEN** the runtime image is asked for `/`, `/some/deep/link` and a built file under `/assets/`
- **THEN** the first two answer 200 with the entry page and `Cache-Control: no-cache`, and the asset answers 200 with an `Expires` far in the future

### Requirement: Source maps are not served
The UI's runtime image SHALL answer 404 for any `.map` file.

#### Scenario: [app-shell-6554e2] A source map is refused
- **WHEN** the runtime image is asked for a path ending in `.map`
- **THEN** it answers 404

### Requirement: The header shows whether the API answers
The UI's header, and the login page, SHALL show the API's status, read from the backend's `health` query: checking while the first answer is pending, online when it reports `ok: true`, and offline when it reports `ok: false` or the request fails.

#### Scenario: [app-shell-3b054c] A healthy API shows online
- **WHEN** a signed-in user loads the UI and the API's `health` query answers `ok: true`
- **THEN** the header shows "Checking API" until the answer arrives, then "API online"

#### Scenario: [app-shell-ca45c7] An unreachable API shows offline
- **WHEN** the UI loads and the `health` request fails or answers `ok: false`
- **THEN** the header shows "API offline"
- **NO E2E** internal-rule: services/ui/tests/unit/components/ApiStatus.test.tsx

### Requirement: A UI built without an API origin sends no request
A UI built without a valid API origin SHALL show "API not configured" on the login page instead of sending any API request.

#### Scenario: [app-shell-c757ea] A build without an API origin
- **WHEN** the UI is built with `VITE_API_URL` empty or not an http(s) origin
- **THEN** the login page shows "API not configured" and the page makes no request to the API
- **NO E2E** internal-rule: services/ui/tests/unit/services/graphql/config.test.ts

### Requirement: A failing layout shows the error screen
The UI SHALL replace the shared layout, when it or its header throws while rendering, with the error screen, without the layout and without the error's details.

#### Scenario: [app-shell-585d60] An error in the layout shows the error screen
- **WHEN** the shared layout or its header throws while rendering
- **THEN** the page shows a "Something went wrong" heading, a reload button and a link to `/`, and not the error's message
- **NO E2E** internal-rule: services/ui/tests/integration/routes.test.tsx
