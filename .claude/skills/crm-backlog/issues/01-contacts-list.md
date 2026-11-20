# Contacts: a list of contacts with an empty state

## Problem

The CRM has no people in it yet. Everything else in the backlog (companies, deals, notes) hangs off contacts, so the app first needs somewhere to keep and show them.

## What we want

- A `contacts` table with a name, an email and a created date.
- A `contacts` query that returns every contact, newest first.
- A "Contacts" link in the navigation and a `/contacts` page listing each contact's name and email.
- With no contacts, the page says "No contacts yet."

## Scope

- Signed-in users only: the API refuses a signed-out request with `UNAUTHENTICATED`, as the `dashboard` query does. Every signed-in user sees the same CRM data.
- Built the way the dashboard is: backend schema and a migration when the issue adds data, a GraphQL resource, the regenerated contract, the UI page, and an end-to-end test per scenario.
- Out of scope: adding, editing and deleting contacts come in later issues; this one only lists them.
