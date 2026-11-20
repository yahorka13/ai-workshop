# Companies: a company's page lists its deals
after: 08-company-page
after: 13-deals

## Problem

From a company, there is no way to see what is being sold to it.

## What we want

- The `Company` type has a `deals` field: its deals, newest first.
- The company page has a "Deals" section listing each deal's title (linking to the deal), stage and value, or "No deals yet."

## Scope

- Signed-in users only: the API refuses a signed-out request with `UNAUTHENTICATED`, as the `dashboard` query does. Every signed-in user sees the same CRM data.
- Built the way the dashboard is: backend schema and a migration when the issue adds data, a GraphQL resource, the regenerated contract, the UI page, and an end-to-end test per scenario.
- Out of scope: read only.
