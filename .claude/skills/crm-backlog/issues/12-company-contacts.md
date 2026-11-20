# Companies: a company's page lists its contacts
after: 11-contact-company

## Problem

From a company, there is no way to see who works there.

## What we want

- The `Company` type has a `contacts` field: its contacts, by name.
- The company page has a "Contacts" section listing each contact's name (linking to the contact) and email, or "No contacts yet."

## Scope

- Signed-in users only: the API refuses a signed-out request with `UNAUTHENTICATED`, as the `dashboard` query does. Every signed-in user sees the same CRM data.
- Built the way the dashboard is: backend schema and a migration when the issue adds data, a GraphQL resource, the regenerated contract, the UI page, and an end-to-end test per scenario.
- Out of scope: read only: contacts are linked from the contact form.
