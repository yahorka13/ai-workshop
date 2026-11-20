# Companies: edit a company
after: 08-company-page

## Problem

A company's name or website cannot be corrected once it is added.

## What we want

- An `updateCompany` mutation taking the id, a name and a website, validated as when adding (the unique name rule included).
- An "Edit" button on the company page opening the form filled in; saving shows the new values.

## Scope

- Signed-in users only: the API refuses a signed-out request with `UNAUTHENTICATED`, as the `dashboard` query does. Every signed-in user sees the same CRM data.
- Built the way the dashboard is: backend schema and a migration when the issue adds data, a GraphQL resource, the regenerated contract, the UI page, and an end-to-end test per scenario.
- Out of scope: name and website only.
