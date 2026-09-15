---
Date: 2026-09-15
Status: Accepted
Related: ADR 005, ADR 006
Triggers:
  - changing how a pane's rows or bars are ordered
  - adding a limit, a "top N", an "other" bucket or paging to a pane
  - adding a sort direction or sorting by something other than the measure
  - a pane rendering too many rows or bars to read
Topics: ordering, limit, panes, urls, query-layer
---

# ADR 007: Ordering and Limits

## Context

A category pane returned its groups in whatever order the database
produced them, and all of them. In the dummy application that is three
statuses. In a real host it was a hundred projects in an arbitrary
order, which is unreadable as a table and meaningless as a bar chart.
Every BI tool sorts a categorical breakdown by its measure and offers
"top N"; a pane that does neither is not finished.

ADR 005 deliberately left this out of the URL grammar and asked that it
be decided rather than added quietly.

## Decision

**A category pane is ordered by its measure, largest first.** Always,
in SQL, using the alias ActiveRecord already gives the aggregate
(`sum_amount`, `count_all`, `average_amount`). There is no option to
turn this off or sort another way: one obvious ordering, and the one
every analyst expects.

**`limit` is a modifier, so it is a query parameter.** Following ADR
005's naming table, an analyst says "top ten customers by revenue":

```
/dashboards/orders/revenue/customer?limit=10
```

`janela_pane Order, :revenue, by: :customer, limit: 10` emits the same.
The limit is applied in SQL after the ordering, so the database does
the work and the pane receives ten rows, not a thousand trimmed in
Ruby. It must be an integer from 1 to 1000. A pane with a limit has it
in its frame id, so "top five" and "all" of the same breakdown can
share a page.

**Time panes are exempt.** A time series is ordered by time and shows
its whole range; ordering it by value would destroy it, and "the top
ten days" is a different question from "revenue per day". A limit on a
time pane is ignored. Narrowing a time range is a filter
(`placed_on_gteq`), which ADR 006 already allows.

**Not decided here, on purpose:** an "other" bucket that sums what the
limit cut off, ascending order, sorting by label, and paging. Each is
plausible; none is needed by the first host. They belong to the ADR
that needs them and should start from the naming table: an analyst
says "bottom five" or "the rest".

## Consequences

- Every existing category pane changes order to measure-descending.
  That is a visible change and the right one; the old order was
  accidental.
- Ordering by the aggregate alias relies on ActiveRecord's naming of
  grouped calculation columns, which has been stable across major
  versions but is not a documented contract. If it changes, the test
  that asserts the order will say so.
- The naming table in ADR 005 gains a row: *top N* is `?limit=N`.
- The unbounded-query concern in issue #8 is now bounded by hosts that
  pass a limit. It remains unbounded for hosts that do not, and the
  question of whether Janela should impose a ceiling stays with that
  issue.
