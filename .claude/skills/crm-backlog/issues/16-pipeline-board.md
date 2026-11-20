# Deals: a pipeline board with a column per stage
after: 15-deal-stage

## Problem

The deals table does not show at a glance where the sales pipeline stands.

## What we want

- A "Pipeline" link in the navigation and a `/pipeline` page with one column per stage, in stage order.
- Each deal is a card in its stage's column with its title, company and value, linking to the deal page.
- A column with no deals says "No deals".

## Scope

- Signed-in users only: the API refuses a signed-out request with `UNAUTHENTICATED`, as the `dashboard` query does. Every signed-in user sees the same CRM data.
- Built the way the dashboard is: backend schema and a migration when the issue adds data, a GraphQL resource, the regenerated contract, the UI page, and an end-to-end test per scenario.
- Out of scope: no drag and drop: stages change on the deal page. Column totals are the next issue.
