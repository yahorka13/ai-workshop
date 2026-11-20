# Dashboard: a chart of deals per stage
after: 24-deal-tiles

## Problem

The tiles give totals but not how the pipeline is spread across stages.

## What we want

- The `dashboard` query gains `dealsByStage`: for each of the five stages, in order, the stage and its number of deals, zero included.
- The dashboard shows a "Deals by stage" chart, labelled with each stage and its count, built like the sign-ups chart.

## Scope

- Signed-in users only: the API refuses a signed-out request with `UNAUTHENTICATED`, as the `dashboard` query does. Every signed-in user sees the same CRM data.
- Built the way the dashboard is: backend schema and a migration when the issue adds data, a GraphQL resource, the regenerated contract, the UI page, and an end-to-end test per scenario.
- Out of scope: counts only, not values.
