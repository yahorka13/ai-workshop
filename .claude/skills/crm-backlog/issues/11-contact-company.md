# Contacts: link a contact to a company
after: 03-contact-page
after: 08-company-page
after: 10-delete-company

## Problem

Contacts and companies exist side by side with no link, so nobody can tell who works where.

## What we want

- A contact has an optional company.
- The add and edit contact forms have a company picker listing every company, plus "No company".
- The contact page shows the company's name, linking to its page; the contacts list shows it in its own column.
- Deleting a company keeps its contacts and leaves them without a company.

## Scope

- Signed-in users only: the API refuses a signed-out request with `UNAUTHENTICATED`, as the `dashboard` query does. Every signed-in user sees the same CRM data.
- Built the way the dashboard is: backend schema and a migration when the issue adds data, a GraphQL resource, the regenerated contract, the UI page, and an end-to-end test per scenario.
- Out of scope: one company per contact. A company's page listing its contacts is the next issue.
