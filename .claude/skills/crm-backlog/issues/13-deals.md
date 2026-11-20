# Deals: list and add deals with a stage and a value
after: 07-companies
after: 10-delete-company

## Problem

The CRM cannot track any sales: there are no deals.

## What we want

- A `deals` table: title (required), value in whole currency units (zero or more), stage, company (required) and created date.
- Stages, in order: Lead, Qualified, Proposal, Won, Lost; a new deal starts as Lead.
- A `deals` query and a `createDeal` mutation.
- A "Deals" link in the navigation and a `/deals` page listing title, company, stage and value, with "No deals yet." when empty, and an "Add deal" form.
- Deleting a company deletes its deals.
- Values are shown as whole numbers with thousands separators and no currency symbol, such as `12,500`; later issues show values the same way.

## Scope

- Signed-in users only: the API refuses a signed-out request with `UNAUTHENTICATED`, as the `dashboard` query does. Every signed-in user sees the same CRM data.
- Built the way the dashboard is: backend schema and a migration when the issue adds data, a GraphQL resource, the regenerated contract, the UI page, and an end-to-end test per scenario.
- Out of scope: changing a deal's stage and the pipeline board come later.
