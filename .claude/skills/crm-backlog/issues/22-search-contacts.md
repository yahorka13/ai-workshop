# Search: find contacts by name or email
after: 02-add-contact

## Problem

Finding one contact means scrolling the whole list.

## What we want

- A `search(query)` query returning a `Search` object whose `contacts` field holds the contacts whose name or email contains the text, ignoring case, at most 20.
- A search box in the header; submitting it opens `/search?q=<text>` listing the matches, each linking to the contact, or "Nothing found."
- A query shorter than 2 characters returns nothing and is not sent.

## Scope

- Signed-in users only: the API refuses a signed-out request with `UNAUTHENTICATED`, as the `dashboard` query does. Every signed-in user sees the same CRM data.
- Built the way the dashboard is: backend schema and a migration when the issue adds data, a GraphQL resource, the regenerated contract, the UI page, and an end-to-end test per scenario.
- Out of scope: contacts only; companies and deals are the next issue.
