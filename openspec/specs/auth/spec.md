# auth Specification

## Purpose
Who is using the app: signing in with email and password, the session that
follows, signing out, who the API sees as the viewer, and the demo user
every local stack is seeded with.

## Requirements

### Requirement: A user signs in with email and password
The API SHALL sign in a user whose email and password match, answering with a session cookie that is HttpOnly and that no script can read.

#### Scenario: [auth-11d5f5] The demo user signs in
- **WHEN** a client posts `demo@example.com` and `password` to `/api/auth/sign-in/email` from the UI's origin, on a stack `bin/up` started
- **THEN** the API answers 200 and sets an HttpOnly session cookie

### Requirement: Wrong credentials do not sign in
The API SHALL refuse a sign-in whose password is wrong or whose email is unknown with 401 and no session cookie, saying nothing about which part was wrong.

#### Scenario: [auth-4d4c2a] A wrong password is refused
- **WHEN** a client posts `demo@example.com` with a wrong password to `/api/auth/sign-in/email`
- **THEN** the API answers 401 and sets no session cookie

#### Scenario: [auth-713df6] An unknown email is refused the same way
- **WHEN** a client posts an email no user has to `/api/auth/sign-in/email`
- **THEN** the API answers 401 with the same body as for a wrong password and sets no session cookie

### Requirement: Nobody signs up
The API SHALL refuse to create a user through sign-up; users come only from the seed.

#### Scenario: [auth-bb4c24] Sign-up is refused
- **WHEN** a client posts a new email, name and password to `/api/auth/sign-up/email`
- **THEN** the API answers with an error status and that email cannot sign in

### Requirement: Sign-in is accepted only from the UI's origin
The API SHALL refuse a sign-in request whose `Origin` is not the UI's origin.

#### Scenario: [auth-e26127] A sign-in from another origin is refused
- **WHEN** a client posts the demo user's credentials to `/api/auth/sign-in/email` with `Origin: http://evil.example`
- **THEN** the API answers 403 and sets no session cookie

### Requirement: Sign-in is rate limited off a local stack
The API SHALL limit repeated sign-in attempts from one address on any stack `bin/up` did not start.

#### Scenario: [auth-cd4770] Repeated sign-ins are limited on another stack
- **WHEN** a client sends more than three sign-in attempts within ten seconds to an API without the local stack marker
- **THEN** the API answers 429 to the attempts over the limit
- **NO E2E** internal-rule: services/backend/tests/integration/auth.test.ts

### Requirement: A local stack does not rate limit sign-in
A stack `bin/up` started SHALL answer every sign-in attempt on its merits, however many come in a row, so the end-to-end suite and a student's retries are never refused as too many.

#### Scenario: [auth-6a165f] A local stack does not limit sign-in
- **WHEN** a client sends five wrong sign-in attempts in a row to a stack `bin/up` started
- **THEN** every one answers 401

### Requirement: The viewer is the signed-in user
The GraphQL `viewer` query SHALL return the id, name and email of the user whose session cookie the request carries, and null when it carries no valid session.

#### Scenario: [auth-8e45ce] A signed-in request sees its user
- **WHEN** a client that signed in as the demo user queries `{ viewer { id name email } }`
- **THEN** the answer's `viewer` has the name "Demo User" and the email `demo@example.com`

#### Scenario: [auth-6fcece] A request without a session sees no viewer
- **WHEN** a client with no session cookie, or an unknown one, queries `{ viewer { id } }`
- **THEN** the answer's `viewer` is null and there is no error

### Requirement: Signing out ends the session
The API SHALL end the session a sign-out request carries, so its cookie no longer identifies anyone.

#### Scenario: [auth-9a6d59] A signed-out session no longer sees the viewer
- **WHEN** a signed-in client posts to `/api/auth/sign-out` and then queries `viewer` with the cookie it held before
- **THEN** the sign-out answers 200 and `viewer` is null

### Requirement: Every local stack has the demo user
A stack `bin/up` starts SHALL have the demo user, `demo@example.com` named "Demo User" with the password `password`, created by `bin/seed` once the stack is healthy.

#### Scenario: [auth-6d9f8a] A fresh stack has the demo user
- **WHEN** `bin/up` starts a stack on fresh volumes
- **THEN** the demo user can sign in without any other step

### Requirement: Seeding changes only what is missing
The seed SHALL create each demo user that does not exist and leave an existing one, including its password, unchanged, printing what it created and what existed.

#### Scenario: [auth-f0bdba] A second seed changes nothing
- **WHEN** the seed runs twice on the same database
- **THEN** the second run creates no user, reports the demo user as existing, and the demo user still signs in
- **NO E2E** internal-rule: services/backend/tests/integration/seed.test.ts

### Requirement: The seed runs only on a local stack
The seed SHALL refuse to write anything unless it runs on a stack `bin/up` started.

#### Scenario: [auth-2bc8df] The seed refuses a stack bin/up did not start
- **WHEN** the backend's seed command runs without the local stack marker that only `bin/up`'s stack sets
- **THEN** it exits non-zero, says it only seeds a local stack, and writes nothing
- **NO E2E** internal-rule: services/backend/tests/integration/seed.test.ts

### Requirement: bin/seed needs this worktree's running stack
`bin/seed` SHALL refuse to run when this worktree has no running stack.

#### Scenario: [auth-c60d80] bin/seed refuses without a running stack
- **WHEN** `bin/seed` runs in a worktree with no stack started by `bin/up`
- **THEN** it exits non-zero and tells the user to run `bin/up`

### Requirement: The UI asks a signed-out user to sign in
The UI SHALL send a signed-out user who opens any route but `/login` to `/login`, keeping the requested path and query so that signing in returns there.

#### Scenario: [auth-891d75] A signed-out visit opens the login page
- **WHEN** a signed-out user opens `/`
- **THEN** the page shows the "Sign in" heading at `/login` with the requested path kept, and no app header

#### Scenario: [auth-5ad99e] Signing in returns to the requested page
- **WHEN** a signed-out user opens `/no-such-page`, then signs in as the demo user
- **THEN** the page shows `/no-such-page` inside the app's layout

### Requirement: The login page signs the user in
The login page SHALL sign in with the entered email and password and open the requested path, or `/` when none was kept or the kept one is not a path inside the app.

#### Scenario: [auth-06588a] The demo user signs in from the login page
- **WHEN** a signed-out user opens `/login`, enters `demo@example.com` and `password` and presses "Sign in"
- **THEN** the page shows the home screen with "Demo User" in the header

#### Scenario: [auth-cea8c2] A kept path outside the app is ignored
- **WHEN** a user opens `/login?next=//evil.example` and signs in
- **THEN** the page shows the home screen, on the app's own origin
- **NO E2E** internal-rule: services/ui/tests/unit/pages/login/LoginPage.test.tsx

### Requirement: The login page explains a failed sign-in
The login page SHALL keep the user on the page and say "Wrong email or password." when the credentials are refused, and "Couldn't reach the server. Try again." when the API fails or cannot be reached.

#### Scenario: [auth-af5987] A wrong password shows an error
- **WHEN** a user enters `demo@example.com` with a wrong password and presses "Sign in"
- **THEN** the page stays at `/login` and shows "Wrong email or password."

#### Scenario: [auth-9f85cb] An unreachable API shows an error
- **WHEN** the sign-in request fails without an answer or the API answers a server error
- **THEN** the page stays at `/login` and shows "Couldn't reach the server. Try again."
- **NO E2E** internal-rule: services/ui/tests/unit/pages/login/LoginPage.test.tsx

### Requirement: A signed-in user does not see the login page
The UI SHALL send a signed-in user who opens `/login` to the kept path, or `/`.

#### Scenario: [auth-49f567] A signed-in user opening the login page goes home
- **WHEN** a signed-in user opens `/login`
- **THEN** the page shows the home screen

### Requirement: The header signs the user out
The header SHALL show the signed-in user's name and a "Sign out" button that ends the session and opens `/login`, after which the app's routes again require signing in.

#### Scenario: [auth-c3a4be] Signing out returns to the login page
- **WHEN** a signed-in user presses "Sign out" in the header, then opens `/`
- **THEN** the page shows the login page both times
