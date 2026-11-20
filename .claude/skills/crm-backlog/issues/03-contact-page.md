# Contacts: a page for each contact
after: 02-add-contact

## Problem

A contact is only a line in a list; there is nowhere to see one contact on its own, and nowhere for later features (notes, company) to live.

## What we want

- A `contact(id)` query returning one contact, or null when there is none.
- Each name in the contacts list links to `/contacts/<id>`, a page with the contact's name, email and created date.
- An unknown id shows "Contact not found." with a link back to the list.

## Scope

- Signed-in users only: the API refuses a signed-out request with `UNAUTHENTICATED`, as the `dashboard` query does. Every signed-in user sees the same CRM data.
- Built the way the dashboard is: backend schema and a migration when the issue adds data, a GraphQL resource, the regenerated contract, the UI page, and an end-to-end test per scenario.
- Out of scope: editing and deleting are separate issues.
