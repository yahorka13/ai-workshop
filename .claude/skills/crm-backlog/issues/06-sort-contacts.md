# Contacts: sort the contacts list by name or newest
after: 02-add-contact

## Problem

With more than a handful of contacts, the newest-first list makes it hard to find someone by name.

## What we want

- The `contacts` query takes a `sort` argument, `NEWEST` or `NAME`, and sorts on the server.
- A sort control on `/contacts` with "Newest" (the default) and "Name A–Z".
- The choice is kept in the URL (`?sort=name`), so a reload or a shared link keeps it.
- Sorting by name ignores case.

## Scope

- Signed-in users only: the API refuses a signed-out request with `UNAUTHENTICATED`, as the `dashboard` query does. Every signed-in user sees the same CRM data.
- Built the way the dashboard is: backend schema and a migration when the issue adds data, a GraphQL resource, the regenerated contract, the UI page, and an end-to-end test per scenario.
- Out of scope: sorting only; searching is a separate issue.
