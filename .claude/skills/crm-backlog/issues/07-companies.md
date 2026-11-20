# Companies: list and add companies

## Problem

The CRM tracks people but not the organisations they work for, which deals are made with.

## What we want

- A `companies` table with a name (required, unique ignoring case), an optional website and a created date.
- A `companies` query and a `createCompany` mutation. The backend's naming rule pluralises by adding `s`, so teach it the English plural of a word ending in a consonant and `y` (`Company` → `companies`), with a unit test.
- A "Companies" link in the navigation and a `/companies` page listing name and website, with "No companies yet." when empty.
- An "Add company" form on that page; a duplicate name shows an error and saves nothing.

## Scope

- Signed-in users only: the API refuses a signed-out request with `UNAUTHENTICATED`, as the `dashboard` query does. Every signed-in user sees the same CRM data.
- Built the way the dashboard is: backend schema and a migration when the issue adds data, a GraphQL resource, the regenerated contract, the UI page, and an end-to-end test per scenario.
- Out of scope: linking contacts to companies comes later.
