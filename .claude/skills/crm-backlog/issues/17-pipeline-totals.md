# Deals: total value and count on each pipeline column
after: 16-pipeline-board

## Problem

The pipeline board shows cards but not how much money sits in each stage.

## What we want

- Each column's header shows the number of deals in it and the sum of their values.
- Values are formatted as on the deals list, such as `12,500`.
- The totals come from the API (a field computed on the server), not from adding up cards in the browser.

## Scope

- Signed-in users only: the API refuses a signed-out request with `UNAUTHENTICATED`, as the `dashboard` query does. Every signed-in user sees the same CRM data.
- Built the way the dashboard is: backend schema and a migration when the issue adds data, a GraphQL resource, the regenerated contract, the UI page, and an end-to-end test per scenario.
- Out of scope: totals per stage only; no filters.
