# Companies: a page for each company
after: 07-companies

## Problem

A company is only a line in a list; later features (its contacts, its deals) need a page to appear on.

## What we want

- A `company(id)` query returning one company, or null.
- Each name in the companies list links to `/companies/<id>`, showing the name, website (as a link) and created date.
- An unknown id shows "Company not found." with a link back to the list.

## Scope

- Signed-in users only: the API refuses a signed-out request with `UNAUTHENTICATED`, as the `dashboard` query does. Every signed-in user sees the same CRM data.
- Built the way the dashboard is: backend schema and a migration when the issue adds data, a GraphQL resource, the regenerated contract, the UI page, and an end-to-end test per scenario.
- Out of scope: editing, deleting and related records are separate issues.
