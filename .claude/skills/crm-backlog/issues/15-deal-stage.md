# Deals: move a deal to another stage
after: 14-deal-page

## Problem

A deal stays a Lead forever: its progress cannot be recorded.

## What we want

- An `updateDeal` mutation that changes a deal's stage.
- The deal page has a stage picker with the five stages; choosing one saves it and the page and the deals list show the new stage.
- Any stage can move to any other, including back.

## Scope

- Signed-in users only: the API refuses a signed-out request with `UNAUTHENTICATED`, as the `dashboard` query does. Every signed-in user sees the same CRM data.
- Built the way the dashboard is: backend schema and a migration when the issue adds data, a GraphQL resource, the regenerated contract, the UI page, and an end-to-end test per scenario.
- Out of scope: only the stage changes here.
