// A day of the API's stats as the dashboard labels it: "Mon 16". The API
// counts UTC days, so the label is formatted in UTC too, or a viewer west
// of UTC would see each bar under the previous day.
const weekday = new Intl.DateTimeFormat("en", {
  weekday: "short",
  timeZone: "UTC",
});
const dayOfMonth = new Intl.DateTimeFormat("en", {
  day: "numeric",
  timeZone: "UTC",
});

/** The short weekday and day of a YYYY-MM-DD UTC day. */
export function dayLabel(day: string): string {
  const date = new Date(`${day}T00:00:00Z`);
  return `${weekday.format(date)} ${dayOfMonth.format(date)}`;
}
