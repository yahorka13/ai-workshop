# Activities: notes on a contact
after: 03-contact-page

## Problem

What was said to a contact lives in someone's head: there is nowhere to write it down.

## What we want

- A `notes` table: text (required, up to 2000 characters), the contact, the author (the signed-in user) and a created time.
- A `createNote` mutation, and a `notes` field on `Contact`, newest first.
- The contact page has a "Notes" section with a text box and "Add note", and the notes below it with author and time, or "No notes yet."
- Deleting a contact deletes its notes.

## Scope

- Signed-in users only: the API refuses a signed-out request with `UNAUTHENTICATED`, as the `dashboard` query does. Every signed-in user sees the same CRM data.
- Built the way the dashboard is: backend schema and a migration when the issue adds data, a GraphQL resource, the regenerated contract, the UI page, and an end-to-end test per scenario.
- Out of scope: notes cannot be edited or deleted in this issue.
