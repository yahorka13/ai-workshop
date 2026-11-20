# Dashboard: recent activity
after: 20-deal-activities

## Problem

After signing in, nothing shows what the team has been doing lately.

## What we want

- The `dashboard` query gains `recentActivities`: the 5 activities created last, newest first.
- The dashboard shows a "Recent activity" card listing each one's type, summary, deal (linking to it) and date, or "No activity yet."

## Scope

- Signed-in users only: the API refuses a signed-out request with `UNAUTHENTICATED`, as the `dashboard` query does. Every signed-in user sees the same CRM data.
- Built the way the dashboard is: backend schema and a migration when the issue adds data, a GraphQL resource, the regenerated contract, the UI page, and an end-to-end test per scenario.
- Out of scope: the existing tiles and chart stay as they are.
