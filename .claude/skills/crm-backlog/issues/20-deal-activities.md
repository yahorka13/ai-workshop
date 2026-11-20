# Activities: log calls, meetings and emails on a deal
after: 14-deal-page

## Problem

There is no record of what has been done to move a deal forward.

## What we want

- An `activities` table: type (Call, Meeting or Email), a date, a short summary (required), the deal, the author (the signed-in user) and a created time.
- A `createActivity` mutation, and an `activities` field on `Deal`, by date with the latest first.
- The deal page has an "Activities" section with a form (type, date defaulting to today, summary) and the list, or "No activities yet."
- When a deal is deleted (with its company), its activities are deleted with it.

## Scope

- Signed-in users only: the API refuses a signed-out request with `UNAUTHENTICATED`, as the `dashboard` query does. Every signed-in user sees the same CRM data.
- Built the way the dashboard is: backend schema and a migration when the issue adds data, a GraphQL resource, the regenerated contract, the UI page, and an end-to-end test per scenario.
- Out of scope: activities on contacts and reminders are out of scope.
