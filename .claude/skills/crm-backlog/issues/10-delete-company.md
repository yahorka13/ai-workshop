# Companies: delete a company
after: 08-company-page

## Problem

Companies added by mistake or no longer relevant cannot be removed.

## What we want

- A `deleteCompany` mutation taking the id.
- A "Delete" button on the company page that asks for confirmation, deletes the company and returns to `/companies`.

## Scope

- Signed-in users only: the API refuses a signed-out request with `UNAUTHENTICATED`, as the `dashboard` query does. Every signed-in user sees the same CRM data.
- Built the way the dashboard is: backend schema and a migration when the issue adds data, a GraphQL resource, the regenerated contract, the UI page, and an end-to-end test per scenario.
- Out of scope: what happens to a deleted company's contacts and deals: the issues that link them to companies decide it.
