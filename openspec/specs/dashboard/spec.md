# dashboard Specification

## Purpose
The dashboard a signed-in user lands on: the stats query that counts users and recent sign-ups, and the screen of stat tiles and a chart that shows them.

## Requirements

### Requirement: The dashboard query counts users and recent sign-ups
The API's `dashboard` query SHALL answer a signed-in request with the total number of users and, for each of the last 7 UTC calendar days ending today, oldest first, the day as `YYYY-MM-DD` and the number of users created on it, zero for a day with none.

#### Scenario: [dashboard-57cd2b] A signed-in request reads the stats
- **WHEN** a signed-in client sends `{ dashboard { totalUsers signUps { day count } } }`
- **THEN** it gets `totalUsers` equal to the number of users, and exactly 7 `signUps` on consecutive days ending today in UTC, each counting the users created that day

### Requirement: Only a signed-in user reads the dashboard
The API SHALL refuse the `dashboard` query to a request without a valid session with a GraphQL error whose `extensions.code` is `UNAUTHENTICATED`, and no stats.

#### Scenario: [dashboard-5ee8ff] A signed-out request is refused
- **WHEN** a client without a valid session sends the `dashboard` query
- **THEN** the answer has `data: null` and an error with `extensions.code` `UNAUTHENTICATED`

### Requirement: The home screen is the dashboard
The UI SHALL show a signed-in user, at `/`, a "Dashboard" screen with a "Total users" tile, a "Sign-ups, last 7 days" tile and a chart of sign-ups per day, all read from one `dashboard` query, with the navigation link "Dashboard" marked current.

#### Scenario: [dashboard-9e4f6d] The dashboard shows the API's stats
- **WHEN** a signed-in user opens `/`
- **THEN** the page shows the "Dashboard" heading, the total users and the sum of the 7 days' sign-ups the `dashboard` query answers, and a chart labelled with each of the 7 days and its count

### Requirement: A dashboard that fails to load says so
The UI SHALL replace the tiles and the chart, when the `dashboard` query fails or answers something else, with a "Couldn't load the dashboard." notice that offers to reload.

#### Scenario: [dashboard-6a87f4] A failed load shows the notice
- **WHEN** the `dashboard` request fails or its answer is malformed
- **THEN** the page shows "Couldn't load the dashboard." and a Reload button, and no tiles
