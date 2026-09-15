---
Date: 2026-09-15
Status: Accepted
Related: ADR 002, ADR 005
Triggers:
  - grouping a measure by a date or time column
  - adding a granularity, a time zone rule or a week start
  - making a time pane clickable or adding drill-down
  - adding a dependency to the query path
Topics: dsl, time, granularity, groupdate, dependencies, charts
---

# ADR 006: Time Dimensions with Groupdate

## Context

A dashboard without time is thin. "Revenue by status" answers one
question; "revenue per month" answers the one people ask first. ADR 002
built dimensions as columns grouped as they are, which is right for
categories and wrong for dates: grouping by a raw `placed_on` yields one
row per day with gaps wherever nothing happened, in whatever order the
database returns them, in the database's time zone.

Bucketing time correctly is harder than it looks. A month boundary
depends on the viewer's time zone, a week depends on which day starts
it, an empty bucket must still appear so a chart does not silently skip
it, and every database spells `date_trunc` differently. ADR 002 named
Groupdate as the conventional answer and deferred the decision until
the work arrived.

## Decision

**A time dimension declares a default granularity.**

```ruby
dimension :placed_on, granularity: :month
```

Granularity is one of `hour`, `day`, `week`, `month`, `quarter`,
`year`. A dimension with a granularity is a time dimension; one without
is a category, exactly as before.

**Granularity is a modifier, so it is a query parameter.** Following
ADR 005's naming table, an analyst says "revenue by placed_on, per
week": the dimension is the path segment, the granularity is
`?granularity=week`. The dimension's declared value is the default.

```
/dashboards/orders/revenue/placed_on
/dashboards/orders/revenue/placed_on?granularity=week&as=line
```

**Groupdate does the bucketing.** `group_by_period(granularity, column)`
handles the time zone, the week start, gap filling with zeros and the
database differences. Janela adds a runtime dependency on it rather
than reimplementing any of that. The week starts on the host's
`Date.beginning_of_week`, which is Monday unless the host says
otherwise. Buckets are labelled in Ruby after the query
(`2026-09-01`, `Sep 2026`, `Q3 2026`, `2026`) so labels do not depend
on the database.

**Charts gain a `line` renderer.** A time series wants a line; the
renderer whitelist becomes `table`, `bar`, `line`. Nothing else about
charts changes.

**Time panes are not yet click sources.** Clicking a category value
adds one Ransack condition, `status_eq=paid`. Clicking a month means
two, `placed_on_gteq` and `placed_on_lt`, and the dashboard's filter
model is a single key and value per toggle. Rather than half-build
drill-down today, a time pane's values render as plain text and its
chart ignores clicks. Time panes still re-scope when any other pane is
clicked. Drill-down, narrowing granularity by clicking a bucket, is
the natural next decision and gets its own ADR.

## Consequences

- Groupdate is a runtime dependency. It is the conventional Rails
  answer, it is small, and reimplementing time-zone-correct bucketing
  across three databases would be far more code than Janela should
  carry.
- Time buckets are gap-filled, so a chart over a quiet period shows
  the quiet rather than compressing it away. A table over a long range
  gets long; the ordering and limit decision (planned next) applies to
  time panes as to any other.
- Time zone follows `Time.zone`, which is what a Rails host already
  configured. SQLite does not support time zone conversion, so a host
  on SQLite gets UTC buckets; the dummy application runs in UTC.
- A declared `placed_on` dimension is Ransack-allowlisted like any
  other, so hosts can pass `placed_on_gteq` and `placed_on_lt` as
  filters today even though clicking does not generate them yet.
- The naming table in ADR 005 predicted this shape (granularity as a
  modifier, not a path word) before the feature existed, which is the
  point of having recorded it.
