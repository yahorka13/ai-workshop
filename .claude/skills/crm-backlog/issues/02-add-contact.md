# Contacts: add a contact
after: 01-contacts-list

## Problem

The contacts list can only ever be empty: there is no way to put a contact in.

## What we want

- A `createContact` mutation taking a name (required) and an email (required, a valid address).
- An "Add contact" button on `/contacts` opening a form; saving it shows the new contact at the top of the list.
- An invalid or missing field shows its error next to the field and saves nothing.

## Scope

- Signed-in users only: the API refuses a signed-out request with `UNAUTHENTICATED`, as the `dashboard` query does. Every signed-in user sees the same CRM data.
- Built the way the dashboard is: backend schema and a migration when the issue adds data, a GraphQL resource, the regenerated contract, the UI page, and an end-to-end test per scenario.
- Out of scope: phone, job title and company come later; only name and email here.
