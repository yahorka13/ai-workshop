# Deals: a page for each deal
after: 13-deals

## Problem

A deal is only a row in a table; moving it along and logging activity on it need a page.

## What we want

- A `deal(id)` query returning one deal, or null.
- Each title in the deals list links to `/deals/<id>`, showing the title, company (linking to it), stage, value and created date.
- An unknown id shows "Deal not found." with a link back to the list.

## Scope

- Signed-in users only: the API refuses a signed-out request with `UNAUTHENTICATED`, as the `dashboard` query does. Every signed-in user sees the same CRM data.
- Built the way the dashboard is: backend schema and a migration when the issue adds data, a GraphQL resource, the regenerated contract, the UI page, and an end-to-end test per scenario.
- Out of scope: editing; the stage changes in the next issue.
