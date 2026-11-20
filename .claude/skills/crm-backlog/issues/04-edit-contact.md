# Contacts: edit a contact
after: 03-contact-page

## Problem

A typo in a contact's name or email stays forever: nothing can change a contact once it is added.

## What we want

- An `updateContact` mutation taking the id, a name and an email, validated as when adding.
- An "Edit" button on the contact page opening the same form, filled in; saving shows the new values on the page and in the list.
- Updating a contact that no longer exists says so and changes nothing.

## Scope

- Signed-in users only: the API refuses a signed-out request with `UNAUTHENTICATED`, as the `dashboard` query does. Every signed-in user sees the same CRM data.
- Built the way the dashboard is: backend schema and a migration when the issue adds data, a GraphQL resource, the regenerated contract, the UI page, and an end-to-end test per scenario.
- Out of scope: only the fields that exist today: name and email.
