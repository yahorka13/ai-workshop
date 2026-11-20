# Dashboard: tiles for open deals and pipeline value
after: 13-deals

## Problem

The dashboard counts users and sign-ups, but says nothing about sales.

## What we want

- The `dashboard` query gains `openDeals` (deals not Won or Lost) and `pipelineValue` (the sum of their values).
- The dashboard shows an "Open deals" tile and a "Pipeline value" tile next to the existing ones; the value is formatted as on the deals list, such as `12,500`.

## Scope

- Signed-in users only: the API refuses a signed-out request with `UNAUTHENTICATED`, as the `dashboard` query does. Every signed-in user sees the same CRM data.
- Built the way the dashboard is: backend schema and a migration when the issue adds data, a GraphQL resource, the regenerated contract, the UI page, and an end-to-end test per scenario.
- Out of scope: the existing tiles and chart stay as they are.
