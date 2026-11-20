# Search: also find companies and deals
after: 13-deals
after: 22-search-contacts

## Problem

Search finds people but not the companies and deals the team asks about just as often.

## What we want

- The `Search` object gains `companies` (name contains the text) and `deals` (title contains it) fields, ignoring case, at most 20 of each.
- The search page groups results under "Contacts", "Companies" and "Deals", each result linking to its page; an empty group is hidden.

## Scope

- Signed-in users only: the API refuses a signed-out request with `UNAUTHENTICATED`, as the `dashboard` query does. Every signed-in user sees the same CRM data.
- Built the way the dashboard is: backend schema and a migration when the issue adds data, a GraphQL resource, the regenerated contract, the UI page, and an end-to-end test per scenario.
- Out of scope: no ranking beyond the grouping.
