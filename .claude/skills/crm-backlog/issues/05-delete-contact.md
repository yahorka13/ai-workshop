# Contacts: delete a contact
after: 03-contact-page

## Problem

Duplicate or mistaken contacts cannot be removed, so the list fills up with noise.

## What we want

- A `deleteContact` mutation taking the id.
- A "Delete" button on the contact page that asks for confirmation, deletes the contact and returns to `/contacts`, where it is gone.
- Cancelling the confirmation deletes nothing.

## Scope

- Signed-in users only: the API refuses a signed-out request with `UNAUTHENTICATED`, as the `dashboard` query does. Every signed-in user sees the same CRM data.
- Built the way the dashboard is: backend schema and a migration when the issue adds data, a GraphQL resource, the regenerated contract, the UI page, and an end-to-end test per scenario.
- Out of scope: no undo and no archive: deleted is gone.
